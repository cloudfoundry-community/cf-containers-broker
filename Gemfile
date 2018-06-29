source 'https://rubygems.org'

gem 'rails', '~> 4'
gem 'rails-api'
gem 'settingslogic'
gem 'omniauth-uaa-oauth2', git: 'https://github.com/cloudfoundry/omniauth-uaa-oauth2'
gem 'nats'
gem 'sass-rails', '>= 5.0.7'
gem 'docker-api'
gem 'tzinfo-data'

group :production do
  gem 'unicorn'
  gem 'lograge'
end

group :development, :test do
  gem 'rspec-rails'
end

group :development do
  gem 'guard-rails', '>= 0.8.1'
  gem 'shotgun'
end

group :test do
  gem 'webmock'
end
