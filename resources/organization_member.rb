resource_name :sentry_organization_member

property :username, String, required: true
property :organization, String, required: true
property :server, String, required: true
property :base_dir, String, default: '/etc/sentry'

property :service_user, String, default: 'sentry'
property :service_group, String, default: 'sentry'

default_action :create

action :create do
  service_dir = ::File.join(new_resource.base_dir, new_resource.server)

  python_execute "Create Sentry@#{new_resource.server} organization <#{new_resource.organization}>member <#{new_resource.username}>" do
    command "cli.py update organization \"#{new_resource.organization}\" --member #{new_resource.username}"
    cwd service_dir
    user new_resource.service_user
    group new_resource.service_group
    environment 'SENTRY_CONF' => service_dir
    action :run
  end
end
