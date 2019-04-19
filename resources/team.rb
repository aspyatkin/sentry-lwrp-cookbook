resource_name :sentry_team

property :team, String, required: true
property :organization, String, required: true
property :server, String, required: true
property :base_dir, String, default: '/etc/sentry'

property :service_user, String, default: 'sentry'
property :service_group, String, default: 'sentry'

default_action :create

action :create do
  service_dir = ::File.join(new_resource.base_dir, new_resource.server)

  python_execute "Create Sentry@#{new_resource.server} team <#{new_resource.team}> in organization <#{new_resource.organization}>" do
    command "cli.py create team \"#{new_resource.organization}\" \"#{new_resource.team}\""
    cwd service_dir
    user new_resource.service_user
    group new_resource.service_group
    environment 'SENTRY_CONF' => service_dir
    action :run
  end
end
