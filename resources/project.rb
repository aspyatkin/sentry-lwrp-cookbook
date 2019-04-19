resource_name :sentry_project

property :project, String, required: true
property :team, String, required: true
property :organization, String, required: true
property :server, String, required: true
property :base_dir, String, default: '/etc/sentry'

property :service_user, String, default: 'sentry'
property :service_group, String, default: 'sentry'

default_action :create

action :create do
  service_dir = ::File.join(new_resource.base_dir, new_resource.server)

  python_execute "Create Sentry@#{new_resource.server} team <#{new_resource.team}> project <#{new_resource.project}> in organization <#{new_resource.organization}>" do
    command "cli.py create project \"#{new_resource.organization}\" \"#{new_resource.team}\" \"#{new_resource.project}\""
    cwd service_dir
    user new_resource.service_user
    group new_resource.service_group
    environment 'SENTRY_CONF' => service_dir
    action :run
  end
end
