source 'https://rubygems.org'

ruby '~> 2.4.6'

gem 'rails', '~> 4'
gem 'rails-api'
gem 'settingslogic'
gem 'omniauth-uaa-oauth2'
gem 'nats'
gem 'sass-rails', '>= 6.0.0'
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
  gem 'guard-rails'
  gem 'shotgun'
end

group :test do
  gem 'webmock'
end
