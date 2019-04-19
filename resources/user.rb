resource_name :sentry_user

property :name, String, name_property: true
property :server, String, required: true
property :base_dir, String, default: '/etc/sentry'
property :password, String, required: true

property :service_user, String, default: 'sentry'
property :service_group, String, default: 'sentry'

default_action :create

action :create do
  service_dir = ::File.join(new_resource.base_dir, new_resource.server)

  env_name_rand = "PWD_#{[*?A..?Z].sample(8).join}"

  env_command = {
    'SENTRY_CONF' => service_dir
  }
  env_command[env_name_rand] = new_resource.password

  python_execute "Create Sentry@#{new_resource.server} superuser <#{new_resource.name}>" do
    command "cli.py create user #{new_resource.name} #{env_name_rand}"
    cwd service_dir
    user new_resource.service_user
    group new_resource.service_group
    environment env_command
    action :run
  end
end
