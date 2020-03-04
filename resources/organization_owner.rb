resource_name :sentry_organization_owner

property :username, String, required: true
property :organization, String, required: true
property :server, String, required: true
property :base_dir, String, default: '/etc/sentry'

property :service_user, String, default: 'sentry'
property :service_group, String, default: 'sentry'

default_action :create

action :create do
  service_dir = ::File.join(new_resource.base_dir, new_resource.server)
  virtualenv_path = ::File.join(service_dir, '.venv')

  env_command = {
    'SENTRY_CONF' => service_dir,
    'HOME' => service_dir
  }

  bash "Create Sentry@#{new_resource.server} organization <#{new_resource.organization}> owner <#{new_resource.username}>" do
    code <<-EOH
      source #{virtualenv_path}/bin/activate
      python cli.py update organization "#{new_resource.organization}" --owner #{new_resource.username}
      deactivate
    EOH
    cwd service_dir
    user new_resource.service_user
    group new_resource.service_group
    environment env_command
    action :run
  end
end
