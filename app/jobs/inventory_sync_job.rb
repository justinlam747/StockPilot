# frozen_string_literal: true

# Fetches inventory from Shopify, persists snapshots, and sends alerts.
class InventorySyncJob < ApplicationJob
  queue_as :default

  retry_on Shopify::GraphqlClient::ShopifyThrottledError,
           wait: :polynomially_longer, attempts: 5
  retry_on Shopify::GraphqlClient::ShopifyApiError,
           wait: 30.seconds, attempts: 3

  def perform(shop_id)
    shop = Shop.active.find(shop_id)
    ActsAsTenant.with_tenant(shop) { sync_inventory(shop) }
  end

  private

  def sync_inventory(shop)
    data = Shopify::InventoryFetcher.new(shop).call
    Inventory::Persister.new(shop).upsert(data)
    Inventory::Snapshotter.new(shop).snapshot(data)
    detect_and_alert(shop)
    shop.update!(synced_at: Time.current)
    Cache::ShopCache.new(shop).warm_inventory_stats
  end

  def detect_and_alert(shop)
    flagged = Inventory::LowStockDetector.new(shop).detect
    Notifications::AlertSender.new(shop).send_low_stock_alerts(flagged)
  end
end
