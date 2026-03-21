# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Full inventory sync pipeline', type: :model do
  let(:shop) do
    create(:shop, settings: {
             'low_stock_threshold' => 10,
             'timezone' => 'America/Toronto',
             'alert_email' => 'owner@example.com'
           })
  end

  let(:product) { create(:product, shop: shop, shopify_product_id: 9001, title: 'Test Widget') }
  let(:variant) do
    create(:variant, shop: shop, product: product,
                     shopify_variant_id: 9002, sku: 'WDG-001', price: 19.99)
  end

  let(:graphql_response) do
    {
      products: [
        {
          'legacyResourceId' => product.shopify_product_id.to_s,
          'title' => 'Test Widget Updated',
          'productType' => 'Gadgets',
          'vendor' => 'TestCo',
          'status' => 'ACTIVE',
          'variants' => {
            'nodes' => [
              {
                'legacyResourceId' => variant.shopify_variant_id.to_s,
                'sku' => 'WDG-001',
                'title' => 'Default',
                'price' => '19.99',
                'inventoryItem' => {
                  'inventoryLevels' => {
                    'nodes' => [
                      {
                        'quantities' => [
                          { 'name' => 'available', 'quantity' => 3 },
                          { 'name' => 'on_hand', 'quantity' => 5 },
                          { 'name' => 'committed', 'quantity' => 2 },
                          { 'name' => 'incoming', 'quantity' => 0 }
                        ]
                      }
                    ]
                  }
                }
              }
            ]
          }
        }
      ]
    }
  end

  before do
    variant # ensure variant exists
    allow_any_instance_of(Shopify::InventoryFetcher).to receive(:call).and_return(graphql_response)
  end

  it 'persists products, snapshots, and detects low stock end-to-end' do
    ActsAsTenant.with_tenant(shop) do
      # Step 1: Fetch and persist inventory data
      data = Shopify::InventoryFetcher.new(shop).call
      Inventory::Persister.new(shop).upsert(data)

      # Product title should be updated
      expect(product.reload.title).to eq('Test Widget Updated')

      # Step 2: Create inventory snapshots
      count = Inventory::Snapshotter.new(shop).snapshot(data)
      expect(count).to eq(1)
      expect(InventorySnapshot.last.available).to eq(3)

      # Step 3: Detect low stock
      flagged = Inventory::LowStockDetector.new(shop).detect
      expect(flagged.size).to eq(1)
      expect(flagged.first[:status]).to eq(:low_stock)
      expect(flagged.first[:available]).to eq(3)

      # Step 4: Send alerts (with email stub)
      mailer_double = double('mailer', deliver_later: nil)
      allow(AlertMailer).to receive(:low_stock).and_return(mailer_double)

      Notifications::AlertSender.new(shop).send_low_stock_alerts(flagged)
      expect(Alert.count).to eq(1)
      expect(Alert.last.alert_type).to eq('low_stock')
      expect(Alert.last.current_quantity).to eq(3)

      # Step 5: Verify deduplication — second call should not create new alerts
      Notifications::AlertSender.new(shop).send_low_stock_alerts(flagged)
      expect(Alert.count).to eq(1)

      # Step 6: Warm cache
      cache = Cache::ShopCache.new(shop)
      stats = cache.warm_inventory_stats
      expect(stats[:low_stock]).to eq(1)
      expect(stats[:out_of_stock]).to eq(0)
    end
  end

  it 'updates synced_at on the shop after successful sync' do
    expect(shop.synced_at).to be_nil

    allow_any_instance_of(Notifications::AlertSender).to receive(:send_low_stock_alerts)

    ActsAsTenant.with_tenant(shop) do
      InventorySyncJob.new.perform(shop.id)
    end

    expect(shop.reload.synced_at).to be_within(5.seconds).of(Time.current)
  end
end
