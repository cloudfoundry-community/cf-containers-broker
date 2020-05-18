source 'https://rubygems.org'

ruby '~> 2.5.5'

gem 'rails', '~> 5', '>= 5.0.1'
gem 'rails-api', '>= 0.4.1'
gem 'settingslogic'
gem 'omniauth-uaa-oauth2'
gem 'nats'
gem 'sass-rails', '>= 6.0.0'
gem 'docker-api'
gem 'tzinfo-data'

group :production do
  gem 'unicorn'
  gem 'lograge', '>= 0.11.2'
end

group :development, :test do
  gem 'rspec-rails', '>= 3.8.2'
end

group :development do
  gem 'guard-rails'
  gem 'shotgun'
end

group :test do
  gem 'webmock'
end
