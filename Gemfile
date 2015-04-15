source 'https://rubygems.org'

gem 'rails'
gem 'rails-api'
gem 'settingslogic'
gem 'omniauth-uaa-oauth2', git: 'https://github.com/cloudfoundry/omniauth-uaa-oauth2'
gem 'cf-registrar', git: 'https://github.com/cloudfoundry/cf-registrar'
gem 'nats'
gem 'sass-rails'
gem 'docker-api'

group :production do
  gem 'unicorn'
end

group :development, :test do
  gem 'rspec-rails'
end

group :development do
  gem 'guard-rails'
  gem 'shotgun'
end

group :test do
  gem 'webmock'
end
