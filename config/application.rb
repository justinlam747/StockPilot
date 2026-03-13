require_relative "boot"

require "rails"
require "active_model/railtie"
require "active_job/railtie"
require "active_record/railtie"
require "action_controller/railtie"
require "action_mailer/railtie"
require "action_view/railtie"
require "rails/test_unit/railtie"

Bundler.require(*Rails.groups)

module ShopifyInventory
  class Application < Rails::Application
    config.load_defaults 7.2
    config.api_only = true

    # shopify_app gem's engine references config.assets, which doesn't
    # exist in API-only mode. Provide a minimal stub so the initializer
    # doesn't crash.
    unless config.respond_to?(:assets)
      config.assets = ActiveSupport::OrderedOptions.new
      config.assets.precompile = []
      config.assets.paths = []
    end

    # Sidekiq as ActiveJob backend
    config.active_job.queue_adapter = :sidekiq

    # Autoload lib directory
    config.autoload_lib(ignore: %w[assets tasks])

    # Time zone
    config.time_zone = "UTC"

    # Generators
    config.generators do |g|
      g.test_framework :rspec
      g.fixture_replacement :factory_bot, dir: "spec/factories"
      g.orm :active_record, primary_key_type: :bigint
    end
  end
end
