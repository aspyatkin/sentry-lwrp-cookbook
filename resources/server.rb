require 'digest'

resource_name :sentry_server

property :name, String, name_property: true

property :version, String, default: '9.0.0'

property :base_dir, String, default: '/etc/sentry'

property :user, String, default: 'sentry'
property :group, String, default: 'sentry'
property :host, String, default: '127.0.0.1'
property :port, Integer, default: 9000

property :secure, [TrueClass, FalseClass], default: true
property :hsts_max_age, Integer, default: 15_768_000
property :oscp_stapling, [TrueClass, FalseClass], default: true
property :resolvers, Array, default: %w[8.8.8.8 1.1.1.1 8.8.4.4 1.0.0.1]
property :resolver_valid, Integer, default: 600
property :resolver_timeout, Integer, default: 10
property :access_log_options, String, default: 'combined'
property :error_log_options, String, default: 'error'

property :postgres_host, String, required: true
property :postgres_port, Integer, required: true
property :postgres_dbname, String, required: true
property :postgres_username, String, required: true
property :postgres_password, String, required: true

property :redis_host, String, required: true
property :redis_port, Integer, required: true
property :redis_db, Integer, default: 0

property :smtp_host, String, required: true
property :smtp_port, Integer, required: true
property :smtp_username, String, required: true
property :smtp_password, String, required: true
property :smtp_tls, [TrueClass, FalseClass], default: false

property :packages, Array, default: %w[
  libxml2
  libxml2-dev
  libxslt-dev
  libxslt1-dev
  libffi-dev
  libjpeg-dev
  libyaml-dev
  libpq-dev
]

property :fqdn, String, required: true
property :web_workers, Integer, default: 2
property :max_stacktrace_frames, Integer, default: 500
property :admin_email, String, required: true
property :mail_from, String, required: true

default_action :install

action :install do
  new_resource.packages.each do |pkg_name|
    package pkg_name do
      action :install
    end
  end

  group new_resource.group do
    system true
    action :create
  end

  user_home = ::File.join('/home', new_resource.user)

  user new_resource.user do
    group new_resource.group
    shell '/bin/bash'
    system true
    manage_home true
    home user_home
    comment 'Sentry'
    action :create
  end

  service_dir = ::File.join(new_resource.base_dir, new_resource.name)

  directory service_dir do
    owner new_resource.user
    group new_resource.group
    mode 0o755
    recursive true
    action :create
  end

  virtualenv_path = ::File.join(service_dir, '.venv')

  python_virtualenv virtualenv_path do
    python '2'
    user new_resource.user
    group new_resource.group
    action :create
  end

  requirements_file = ::File.join(service_dir, 'requirements.txt')

  template requirements_file do
    cookbook 'sentry-lwrp'
    source 'requirements.txt.erb'
    owner new_resource.user
    group new_resource.group
    variables(
      version: new_resource.version
    )
    mode 0o644
    action :create
  end

  pip_requirements requirements_file do
    user new_resource.user
    group new_resource.group
    virtualenv virtualenv_path
    action :install
  end

  conf_file = ::File.join(service_dir, 'sentry.conf.py')

  template conf_file do
    cookbook 'sentry-lwrp'
    source 'sentry.conf.py.erb'
    owner new_resource.user
    group new_resource.group
    variables(
      sentry_host: new_resource.host,
      sentry_port: new_resource.port,
      sentry_web_workers: new_resource.web_workers,
      sentry_uwsgi: true,
      sentry_max_stacktrace_frames: new_resource.max_stacktrace_frames,
      pg_host: new_resource.postgres_host,
      pg_port: new_resource.postgres_port,
      pg_dbname: new_resource.postgres_dbname,
      pg_username: new_resource.postgres_username,
      pg_password: new_resource.postgres_password,
      redis_host: new_resource.redis_host,
      redis_port: new_resource.redis_port,
      redis_db: new_resource.redis_db,
      secure: new_resource.secure
    )
    sensitive true
    mode 0o644
  end

  secret_key_file = ::File.join(service_dir, '.secret')

  python_execute "Create Sentry@#{new_resource.name} secret key" do
    command "-m sentry config generate-secret-key > #{secret_key_file}"
    cwd service_dir
    user new_resource.user
    group new_resource.group
    action :run
    not_if { ::File.exist?(secret_key_file) }
  end

  new_conf_file = ::File.join(service_dir, 'config.yml')

  template new_conf_file do
    cookbook 'sentry-lwrp'
    source 'sentry.config.yml.erb'
    owner new_resource.user
    group new_resource.group
    variables(lazy {
      {
        admin_email: new_resource.admin_email,
        secret_key: ::IO.read(secret_key_file),
        url_prefix: "http#{new_resource.secure ? 's' : ''}://#{new_resource.fqdn}",
        redis_host: new_resource.redis_host,
        redis_port: new_resource.redis_port,
        redis_db: new_resource.redis_db,
        smtp_host: new_resource.smtp_host,
        smtp_port: new_resource.smtp_port,
        smtp_username: new_resource.smtp_username,
        smtp_password: new_resource.smtp_password,
        smtp_tls: new_resource.smtp_tls,
        mail_from: new_resource.mail_from
      }
    })
    sensitive true
    action :create
  end

  python_execute "Run Sentry@#{new_resource.name} database migration" do
    command '-m sentry upgrade --noinput'
    cwd service_dir
    user new_resource.user
    group new_resource.group
    environment(
      'SENTRY_CONF' => service_dir
    )
    action :run
  end

  systemd_unit 'sentry-cron.service' do
    content({
      Unit: {
        Description: 'Sentry Beat Service',
        After: [
          'network.target',
          'postgresql.service',
          "redis@#{new_resource.redis_port}.service"
        ],
        PartOf: 'sentry.target'
      },
      Service: {
        Type: 'simple',
        User: new_resource.user,
        Group: new_resource.group,
        WorkingDirectory: virtualenv_path,
        Environment: "SENTRY_CONF=#{service_dir}",
        ExecStart: "#{::File.join(virtualenv_path, 'bin', 'sentry')} run cron"
      },
      Install: {
        WantedBy: 'multi-user.target'
      }
    })
    verify true
    action %i[create enable start]
  end

  systemd_unit 'sentry-worker.service' do
    content({
      Unit: {
        Description: 'Sentry Background Worker',
        After: [
          'network.target',
          'postgresql.service',
          "redis@#{new_resource.redis_port}.service"
        ],
        PartOf: 'sentry.target'
      },
      Service: {
        Type: 'simple',
        User: new_resource.user,
        Group: new_resource.group,
        WorkingDirectory: virtualenv_path,
        Environment: "SENTRY_CONF=#{service_dir}",
        ExecStart: "#{::File.join(virtualenv_path, 'bin', 'sentry')} run worker"
      },
      Install: {
        WantedBy: 'multi-user.target'
      }
    })
    verify true
    action %i[create enable start]
  end

  systemd_unit 'sentry-web.service' do
    content({
      Unit: {
        Description: 'Sentry Main Service',
        After: [
          'network.target',
          'postgresql.service',
          "redis@#{new_resource.redis_port}.service",
          'sentry-cron.service',
          'sentry-worker.service'
        ],
        PartOf: 'sentry.target'
      },
      Service: {
        Type: 'simple',
        User: new_resource.user,
        Group: new_resource.group,
        WorkingDirectory: virtualenv_path,
        Environment: "SENTRY_CONF=#{service_dir}",
        ExecStart: "#{::File.join(virtualenv_path, 'bin', 'sentry')} run web"
      },
      Install: {
        WantedBy: 'multi-user.target'
      }
    })
    verify true
    action %i[create enable start]
  end

  systemd_unit 'sentry.target' do
    content(lazy {
      {
        Unit: {
          Description: 'Sentry',
          Wants: [
            'sentry-cron.service',
            'sentry-worker.service',
            'sentry-web.service'
          ]
        },
        Install: {
          WantedBy: 'multi-user.target'
        }
      }
    })
    action %i[create enable start]
    subscribes :restart, ["template[#{conf_file}]", "template[#{new_conf_file}]"], :delayed
  end

  vhost_vars = {
    fqdn: new_resource.fqdn,
    sentry_host: new_resource.host,
    sentry_port: new_resource.port,
    secure: new_resource.secure,
    access_log_options: new_resource.access_log_options,
    error_log_options: new_resource.error_log_options,
  }

  if new_resource.secure
    vhost_vars.merge!(
      certificate_entries: [],
      hsts_max_age: new_resource.hsts_max_age,
      oscp_stapling: new_resource.oscp_stapling,
      resolvers: new_resource.resolvers,
      resolver_valid: new_resource.resolver_valid,
      resolver_timeout: new_resource.resolver_timeout
    )

    tls_rsa_certificate new_resource.fqdn do
      action :deploy
    end

    tls = ::ChefCookbook::TLS.new(node)
    vhost_vars[:certificate_entries] << tls.rsa_certificate_entry(new_resource.fqdn)

    if tls.has_ec_certificate?(new_resource.fqdn)
      tls_ec_certificate new_resource.fqdn do
        action :deploy
      end

      vhost_vars[:certificate_entries] << tls.ec_certificate_entry(new_resource.fqdn)
    end
  end

  nginx_vhost "sentry.#{new_resource.name}" do
    cookbook 'sentry-lwrp'
    template 'nginx.conf.erb'
    variables(lazy {
      vhost_vars.merge(
        access_log: ::File.join(node.run_state['nginx']['log_dir'], "sentry.#{new_resource.name}_access.log"),
        error_log: ::File.join(node.run_state['nginx']['log_dir'], "sentry.#{new_resource.name}_error.log")
      )
    })
    action :enable
  end

  cli_script = ::File.join(service_dir, 'cli.py')

  require 'versionomy'
  cli_script_version = ::Versionomy.parse(new_resource.version).major

  cookbook_file cli_script do
    cookbook 'sentry-lwrp'
    source "sentry_cli_#{cli_script_version}.py"
    owner new_resource.user
    group new_resource.group
    mode 0o644
    action :create
  end
end
