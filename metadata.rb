name 'sentry-lwrp'
maintainer 'Alexander Pyatkin'
maintainer_email 'aspyatkin@gmail.com'
license 'MIT'
version '0.1.0'
description 'Installs and configures Sentry server'

source_url 'https://github.com/aspyatkin/sentry-lwrp-cookbook' if respond_to?(:source_url)
depends 'poise-python', '>= 1.7.0'
depends 's3backup', '~> 2.2.0'
depends 'ngx', '>= 2.1.0'
depends 'tls', '>= 3.2.0'

gem 'versionomy'

supports 'ubuntu'
