# frozen_string_literal: true

require_relative 'boot'

require 'rails'
require 'active_model/railtie'
require 'active_job/railtie'
require 'active_record/railtie'
require 'action_controller/railtie'
require 'action_mailer/railtie'
require 'action_view/railtie'
require 'rails/test_unit/railtie'

Bundler.require(*Rails.groups)

# Skip the Clerk Railtie's automatic middleware insertion so the initializer
# can decide whether the legacy auth middleware should run after env loading.
ENV['CLERK_SKIP_RAILTIE'] = '1'
begin
  require 'clerk/rack_middleware'
rescue LoadError
  # Clerk gem not installed - skip middleware in environments that do not use it.
end

module ShopifyInventory
  # Main application configuration for the Catalog Audit Shopify app.
  class Application < Rails::Application
    config.load_defaults 7.2

    # Sidekiq as ActiveJob backend
    config.active_job.queue_adapter = :sidekiq

    # Autoload lib directory
    config.autoload_lib(ignore: %w[assets tasks])

    # Time zone
    config.time_zone = 'UTC'

    # Generators
    config.generators do |g|
      g.test_framework :rspec
      g.fixture_replacement :factory_bot, dir: 'spec/factories'
      g.orm :active_record, primary_key_type: :bigint
    end
  end
end
