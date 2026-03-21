# frozen_string_literal: true

# Post-OAuth setup: registers webhooks and triggers initial inventory sync.
class AfterAuthenticateJob < ApplicationJob
  queue_as :default

  def perform(shop_domain:)
    shop = Shop.find_by!(shop_domain: shop_domain)
    Shopify::WebhookRegistrar.call(shop)
    InventorySyncJob.perform_later(shop.id)
  end
end
