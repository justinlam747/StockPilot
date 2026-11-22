require_relative 'boot'
require 'rails'
require 'active_record/railtie'
require 'active_job/railtie'
require 'action_controller/railtie'
require 'action_view/railtie'

Bundler.require(*Rails.groups)

module StockPilotShopify
  class Application < Rails::Application
    config.load_defaults 7.2
    config.active_job.queue_adapter = :sidekiq
    config.active_record.dump_schema_after_migration = false
    config.filter_parameters += %i[access_token token secret hmac code state]
    config.session_store :cookie_store, key: '_stockpilot_shopify', same_site: :lax, httponly: true
    config.log_level = :info
    config.eager_load = Rails.env.production?
  end
end
