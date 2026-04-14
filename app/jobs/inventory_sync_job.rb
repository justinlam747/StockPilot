# frozen_string_literal: true

# Single orchestration point for Shopify catalog sync.
#
# Keep this job thin: it fetches the current catalog, persists it, and
# updates the sync timestamp. All catalog writes should flow through here
# so webhook-triggered and manual syncs stay aligned.
#
class InventorySyncJob < ApplicationJob
  queue_as :default

  # retry_on tells Sidekiq to automatically retry the job if it fails
  # with specific errors, instead of crashing immediately.
  #
  # For throttle errors (Shopify rate limit): wait longer each time
  # (polynomially_longer = 1s, 4s, 9s, 16s, 25s) up to 5 attempts.
  #
  # For API errors (something broke on Shopify's side): wait 30 seconds,
  # try 3 times total, then give up and send to the dead letter queue.
  #
  retry_on Shopify::GraphqlClient::ShopifyThrottledError,
           wait: :polynomially_longer, attempts: 5
  retry_on Shopify::GraphqlClient::ShopifyApiError,
           wait: 30.seconds, attempts: 3

  def perform(shop_id)
    shop = Shop.active.find(shop_id)
    sync_catalog(shop)
  end

  private

  # The persister owns tenant scoping and reconciliation of missing products.
  # Do not reintroduce snapshots, alerts, or cache warming here; that would
  # split the sync contract and make the product harder to explain.
  def sync_catalog(shop)
    data = Shopify::InventoryFetcher.new(shop).fetch_all_products
    Inventory::Persister.new(shop).upsert_catalog(data)
    shop.update!(synced_at: Time.current)
  end
end
