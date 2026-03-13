source "https://rubygems.org"

ruby ">= 3.3.0"

gem "rails", "~> 7.2.0"
gem "pg", "~> 1.5"
gem "puma", ">= 6.0"
gem "redis", ">= 5.0"
gem "sidekiq", "~> 7.0"
gem "sidekiq-cron", "~> 1.12"
gem "shopify_app", "~> 22.0"
gem "shopify_api", "~> 14.0"
gem "vite_ruby", "~> 3.0"
gem "httparty", "~> 0.22"
gem "anthropic", "~> 0.3"
gem "acts_as_tenant", "~> 1.0"
gem "kaminari", "~> 1.2"
gem "blueprinter", "~> 1.0"
gem "bootsnap", require: false
gem "tzinfo-data", platforms: %i[windows jruby]
gem "rack-cors"
gem "rack-attack", "~> 6.7"
gem "sentry-ruby", "~> 5.0"
gem "sentry-rails", "~> 5.0"
gem "sentry-sidekiq", "~> 5.0"

group :development, :test do
  gem "rspec-rails", "~> 7.0"
  gem "factory_bot_rails", "~> 6.0"
  gem "webmock", "~> 3.0"
  gem "dotenv-rails", "~> 3.0"
  gem "debug", platforms: %i[mri windows]
  gem "rubocop-rails-omakase", require: false
end

group :test do
  gem "shoulda-matchers", "~> 6.0"
  gem "simplecov", require: false
end
