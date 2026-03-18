# frozen_string_literal: true

class InventorySyncJob < ApplicationJob
  queue_as :default

  retry_on Shopify::GraphqlClient::ShopifyThrottledError,
           wait: :polynomially_longer, attempts: 5
  retry_on Shopify::GraphqlClient::ShopifyApiError,
           wait: 30.seconds, attempts: 3

  def perform(shop_id)
    shop = Shop.active.find(shop_id)

    ActsAsTenant.with_tenant(shop) do
      data = Shopify::InventoryFetcher.new(shop).call
      Inventory::Persister.new(shop).upsert(data)
      Inventory::Snapshotter.new(shop).snapshot(data)

      flagged = Inventory::LowStockDetector.new(shop).detect
      Notifications::AlertSender.new(shop).send_low_stock_alerts(flagged)

      shop.update!(synced_at: Time.current)
      Cache::ShopCache.new(shop).warm_inventory_stats
    end
  end
end
