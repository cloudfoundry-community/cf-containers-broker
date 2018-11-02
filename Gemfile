source 'https://rubygems.org'

gem 'rails', '~> 4', '>= 4.2.10'
gem 'rails-api', '>= 0.4.1'
gem 'settingslogic'
gem 'omniauth-uaa-oauth2', git: 'https://github.com/cloudfoundry/omniauth-uaa-oauth2'
gem 'nats'
gem 'sass-rails', '>= 5.0.7'
gem 'docker-api'
gem 'tzinfo-data'

group :production do
  gem 'unicorn'
  gem 'lograge', '>= 0.10.0'
end

group :development, :test do
  gem 'rspec-rails', '>= 3.7.2'
end

group :development do
  gem 'guard-rails'
  gem 'shotgun'
end

group :test do
  gem 'webmock'
end
