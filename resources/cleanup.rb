resource_name :sentry_cleanup

property :server, String, name_property: true
property :base_dir, String, default: '/etc/sentry'

property :service_user, String, default: 'sentry'
property :service_group, String, default: 'sentry'

property :enable, [TrueClass, FalseClass], default: true
property :days, Integer, default: 30
property :schedule, Hash, required: true

default_action :configure

action :configure do
  service_dir = ::File.join(new_resource.base_dir, new_resource.server)
  cleanup_script = ::File.join(service_dir, 'cleanup')
  virtualenv_path = ::File.join(service_dir, '.venv')

  template cleanup_script do
    cookbook 'sentry-lwrp'
    source 'cleanup.sh.erb'
    owner new_resource.service_user
    group new_resource.service_group
    mode 0o755
    variables(
      target_user: new_resource.service_user,
      virtualenv_path: virtualenv_path,
      sentry_conf_dir: service_dir,
      sentry_cleanup_days: new_resource.days
    )
    if new_resource.enable
      action :create
    else
      action :delete
    end
  end

  full_command = nil
  schedule = new_resource.schedule

  ruby_block "construct cleanup_sentry_#{new_resource.server} command" do
    block do
      helper = nil
      if !node.run_state['ssmtp'].nil? && node.run_state['ssmtp']['installed']
        helper = ::ChefCookbook::SSMTP::Helper.new(node)
      end
      cronic_installed = !node.run_state['cronic'].nil? && node.run_state['cronic']['installed']

      full_command = "#{cronic_installed ? "#{node.run_state['cronic']['command']} " : ''}#{cleanup_script}"
      unless helper.nil? || schedule.fetch(:mailto, nil).nil? || schedule.fetch(:mailfrom, nil).nil?
        full_command += " 2>&1 | #{helper.mail_send_command("Cron cleanup_sentry_#{new_resource.server}", schedule[:mailfrom], schedule[:mailto], cronic_installed)}"
      end
    end
    action :run
  end

  cron "cleanup_sentry_#{new_resource.server}" do
    command lazy { full_command }
    minute schedule[:minute]
    hour schedule[:hour]
    day schedule[:day]
    month schedule[:month]
    weekday schedule[:weekday]
    if new_resource.enable
      action :create
    else
      action :delete
    end
  end
end
