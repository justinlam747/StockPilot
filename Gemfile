# frozen_string_literal: true

source 'https://rubygems.org'

ruby '>= 3.3.0'

gem 'acts_as_tenant', '~> 1.0'
gem 'blueprinter', '~> 1.0'
gem 'bootsnap', require: false
gem 'httparty', '~> 0.22'
gem 'kaminari', '~> 1.2'
gem 'omniauth-rails_csrf_protection'
gem 'omniauth-shopify-oauth2'
gem 'clerk-sdk-ruby', '~> 4.0'
gem 'svix', '~> 1.0'
gem 'pg', '~> 1.5'
gem 'propshaft'
gem 'puma', '>= 6.0'
gem 'rack-attack', '~> 6.7'
gem 'rack-cors'
gem 'rails', '~> 7.2.0'
gem 'redis', '>= 5.0'
gem 'sentry-rails', '~> 5.0'
gem 'sentry-ruby', '~> 5.0'
gem 'sentry-sidekiq', '~> 5.0'
gem 'shopify_api', '~> 14.0'
gem 'sidekiq', '~> 7.0'
gem 'sidekiq-cron', '~> 1.12'
gem 'tzinfo-data', platforms: %i[windows jruby]

group :development, :test do
  gem 'brakeman', require: false
  gem 'debug', platforms: %i[mri windows]
  gem 'dotenv-rails', '~> 3.0'
  gem 'factory_bot_rails', '~> 6.0'
  gem 'rspec-rails', '~> 7.0'
  gem 'rubocop-rails-omakase', require: false
  gem 'webmock', '~> 3.0'
end

group :test do
  gem 'shoulda-matchers', '~> 6.0'
  gem 'simplecov', require: false
end
