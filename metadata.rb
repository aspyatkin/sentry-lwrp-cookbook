name 'sentry-lwrp'
maintainer 'Alexander Pyatkin'
maintainer_email 'aspyatkin@gmail.com'
license 'MIT'
version '0.4.2'
description 'Installs and configures Sentry server'

source_url 'https://github.com/aspyatkin/sentry-lwrp-cookbook' if respond_to?(:source_url)
depends 's3backup', '~> 3.1'
depends 'ngx', '~> 2.2'
depends 'tls', '~> 4.1'

gem 'versionomy'

supports 'ubuntu'
