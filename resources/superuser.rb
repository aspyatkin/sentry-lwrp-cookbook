resource_name :sentry_superuser

property :name, String, name_property: true
property :server, String, required: true
property :base_dir, String, default: '/etc/sentry'
property :password, String, required: true

property :service_user, String, default: 'sentry'
property :service_group, String, default: 'sentry'

default_action :create

action :create do
  service_dir = ::File.join(new_resource.base_dir, new_resource.server)
  virtualenv_path = ::File.join(service_dir, '.venv')

  env_name_rand = "PWD_#{[*?A..?Z].sample(8).join}"

  env_command = {
    'SENTRY_CONF' => service_dir,
    'HOME' => service_dir
  }
  env_command[env_name_rand] = new_resource.password

  bash "Create Sentry@#{new_resource.server} superuser <#{new_resource.name}>" do
    code <<-EOH
      source #{virtualenv_path}/bin/activate
      python cli.py create superuser #{new_resource.name} #{env_name_rand}
      deactivate
    EOH
    cwd service_dir
    user new_resource.service_user
    group new_resource.service_group
    environment env_command
    action :run
  end
end
