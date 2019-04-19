resource_name :sentry_backup

property :server, String, name_property: true
property :base_dir, String, default: '/etc/sentry'

property :service_user, String, default: 'sentry'
property :service_group, String, default: 'sentry'

property :postgres_host, String, required: true
property :postgres_port, Integer, required: true
property :postgres_dbname, String, required: true
property :postgres_username, String, required: true
property :postgres_password, String, required: true

property :aws_iam_access_key_id, String, required: true
property :aws_iam_secret_access_key, String, required: true
property :aws_s3_bucket_region, String, required: true
property :aws_s3_bucket_name, String, required: true

property :schedule, Hash, required: true

default_action :configure

action :configure do
  service_dir = ::File.join(new_resource.base_dir, new_resource.server)
  backup_script = ::File.join(service_dir, 'backup')

  template backup_script do
    cookbook 'sentry-lwrp'
    source 'backup.sh.erb'
    owner new_resource.service_user
    group new_resource.service_group
    mode 0o755
    variables(
      pg_dbname: new_resource.postgres_dbname,
      pg_host: new_resource.postgres_host,
      pg_port: new_resource.postgres_port,
      pg_username: new_resource.postgres_username,
      pg_password: new_resource.postgres_password
    )
    action :create
  end

  s3backup_item "backup_sentry_#{new_resource.server}" do
    backup_command backup_script
    aws_iam_access_key_id new_resource.aws_iam_access_key_id
    aws_iam_secret_access_key new_resource.aws_iam_secret_access_key
    aws_s3_bucket_region new_resource.aws_s3_bucket_region
    aws_s3_bucket_name new_resource.aws_s3_bucket_name
    schedule new_resource.schedule
    action :create
  end
end
