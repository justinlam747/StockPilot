# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Race conditions and idempotency', type: :model do
  include ActiveSupport::Testing::TimeHelpers

  let(:shop) do
    create(:shop, settings: {
             'low_stock_threshold' => 10,
             'timezone' => 'America/Toronto',
             'alert_email' => 'owner@example.com'
           })
  end

  let(:product) do
    create(:product, shop: shop, shopify_product_id: 5001, title: 'Widget Pro', status: 'active')
  end

  let(:variant) do
    create(:variant,
           shop: shop,
           product: product,
           shopify_variant_id: 6001,
           sku: 'WGT-PRO-001',
           title: 'Default',
           price: 29.99)
  end

  # --------------------------------------------------------------------------
  # 1. AlertSender deduplication
  # --------------------------------------------------------------------------
  describe 'AlertSender deduplication' do
    let(:flagged_variants) do
      [
        {
          variant: variant,
          available: 3,
          on_hand: 5,
          status: :low_stock,
          threshold: 10
        }
      ]
    end

    before do
      ActsAsTenant.with_tenant(shop) do
        create(:inventory_snapshot, shop: shop, variant: variant, available: 3, on_hand: 5)
      end
    end

    it 'creates exactly one alert when called twice with the same flagged variant' do
      ActsAsTenant.with_tenant(shop) do
        sender = Notifications::AlertSender.new(shop)

        allow(AlertMailer).to receive_message_chain(:low_stock, :deliver_later)

        sender.create_alerts_and_notify(flagged_variants)
        expect(Alert.where(variant: variant).count).to eq(1)

        sender.create_alerts_and_notify(flagged_variants)
        expect(Alert.where(variant: variant).count).to eq(1)
      end
    end

    it 'does not send a second email when called twice' do
      ActsAsTenant.with_tenant(shop) do
        mailer_double = double('mailer', deliver_later: nil)
        allow(AlertMailer).to receive(:low_stock).and_return(mailer_double)

        sender = Notifications::AlertSender.new(shop)
        sender.create_alerts_and_notify(flagged_variants)
        sender.create_alerts_and_notify(flagged_variants)

        expect(AlertMailer).to have_received(:low_stock).once
      end
    end
  end

  # --------------------------------------------------------------------------
  # 2. SnapshotCleanupJob idempotency
  # --------------------------------------------------------------------------
  describe 'SnapshotCleanupJob idempotency' do
    before do
      ActsAsTenant.with_tenant(shop) do
        3.times do
          create(:inventory_snapshot,
                 shop: shop,
                 variant: variant,
                 created_at: 100.days.ago,
                 snapshotted_at: 100.days.ago)
        end

        2.times do
          create(:inventory_snapshot,
                 shop: shop,
                 variant: variant,
                 created_at: 10.days.ago,
                 snapshotted_at: 10.days.ago)
        end
      end
    end

    it 'deletes old snapshots on first run and succeeds with no-op on second run' do
      SnapshotCleanupJob.new.perform
      expect(InventorySnapshot.count).to eq(2)

      expect { SnapshotCleanupJob.new.perform }.not_to raise_error
      expect(InventorySnapshot.count).to eq(2)
    end

    it 'preserves recent snapshots across multiple runs' do
      3.times { SnapshotCleanupJob.new.perform }

      remaining = InventorySnapshot.where(variant: variant)
      expect(remaining.count).to eq(2)
      expect(remaining.pluck(:created_at)).to all(be > 91.days.ago)
    end
  end

  # --------------------------------------------------------------------------
  # 3. Inventory::Persister upsert idempotency
  # --------------------------------------------------------------------------
  describe 'Inventory::Persister upsert idempotency' do
    let(:graphql_data) do
      {
        products: [
          {
            'legacyResourceId' => '5001',
            'title' => 'Widget Pro',
            'productType' => 'Gadgets',
            'vendor' => 'WidgetCo',
            'status' => 'ACTIVE',
            'variants' => {
              'nodes' => [
                {
                  'legacyResourceId' => '6001',
                  'sku' => 'WGT-PRO-001',
                  'title' => 'Default',
                  'price' => '29.99'
                }
              ]
            }
          }
        ]
      }
    end

    it 'creates product and variant on first upsert, updates on second without duplicates' do
      ActsAsTenant.with_tenant(shop) do
        persister = Inventory::Persister.new(shop)

        persister.upsert(graphql_data)
        expect(Product.count).to eq(1)
        expect(Variant.count).to eq(1)

        product_record = Product.find_by(shopify_product_id: '5001')
        expect(product_record.title).to eq('Widget Pro')

        persister.upsert(graphql_data)
        expect(Product.count).to eq(1)
        expect(Variant.count).to eq(1)
      end
    end

    it 'updates attributes on re-upsert without creating new rows' do
      ActsAsTenant.with_tenant(shop) do
        persister = Inventory::Persister.new(shop)
        persister.upsert(graphql_data)

        first_synced_at = Product.find_by(shopify_product_id: '5001').synced_at

        updated_data = graphql_data.deep_dup
        updated_data[:products][0]['title'] = 'Widget Pro v2'

        travel_to(1.minute.from_now) do
          persister.upsert(updated_data)
        end

        expect(Product.count).to eq(1)
        product_record = Product.find_by(shopify_product_id: '5001')
        expect(product_record.title).to eq('Widget Pro v2')
        expect(product_record.synced_at).to be > first_synced_at
      end
    end

    it 'handles upsert_single_product idempotently' do
      ActsAsTenant.with_tenant(shop) do
        persister = Inventory::Persister.new(shop)

        shopify_data = {
          'id' => '7001',
          'title' => 'Single Widget',
          'product_type' => 'Gadgets',
          'vendor' => 'WidgetCo',
          'status' => 'active',
          'variants' => [
            { 'id' => '8001', 'sku' => 'SNG-001', 'title' => 'Default', 'price' => '15.00' }
          ]
        }

        persister.upsert_single_product(shopify_data, source: :webhook)
        expect(Product.where(shopify_product_id: '7001').count).to eq(1)
        expect(Variant.where(shopify_variant_id: '8001').count).to eq(1)

        persister.upsert_single_product(shopify_data, source: :webhook)
        expect(Product.where(shopify_product_id: '7001').count).to eq(1)
        expect(Variant.where(shopify_variant_id: '8001').count).to eq(1)
      end
    end
  end

  # --------------------------------------------------------------------------
  # 4. WeeklyReportJob idempotency
  # --------------------------------------------------------------------------
  describe 'WeeklyReportJob idempotency' do
    let(:week_start) { Time.current.beginning_of_week(:monday) }

    before do
      ActsAsTenant.with_tenant(shop) do
        create(:inventory_snapshot,
               shop: shop,
               variant: variant,
               available: 50,
               on_hand: 55,
               snapshotted_at: week_start + 1.hour)
      end
    end

    it 'generates reports and sends email on first run' do
      ActsAsTenant.with_tenant(shop) do
        mailer_double = double('mailer', deliver_later: nil)
        allow(ReportMailer).to receive(:weekly_summary).and_return(mailer_double)

        WeeklyReportJob.new.perform(shop.id)

        expect(ReportMailer).to have_received(:weekly_summary).once
      end
    end

    it 'can run twice without errors (idempotent)' do
      ActsAsTenant.with_tenant(shop) do
        mailer_double = double('mailer', deliver_later: nil)
        allow(ReportMailer).to receive(:weekly_summary).and_return(mailer_double)

        expect { WeeklyReportJob.new.perform(shop.id) }.not_to raise_error
        expect { WeeklyReportJob.new.perform(shop.id) }.not_to raise_error
      end
    end
  end

  # --------------------------------------------------------------------------
  # 5. DailySyncAllShopsJob -- no duplicate enqueues per run
  # --------------------------------------------------------------------------
  describe 'DailySyncAllShopsJob' do
    let!(:shop_a) { create(:shop) }
    let!(:shop_b) { create(:shop) }
    let!(:uninstalled_shop) { create(:shop, uninstalled_at: 1.day.ago) }

    before do
      allow(InventorySyncJob).to receive(:perform_later)
    end

    it 'enqueues one sync job per active shop per run' do
      DailySyncAllShopsJob.new.perform

      expect(InventorySyncJob).to have_received(:perform_later).with(shop_a.id).once
      expect(InventorySyncJob).to have_received(:perform_later).with(shop_b.id).once
    end

    it 'does not enqueue for uninstalled shops' do
      DailySyncAllShopsJob.new.perform

      expect(InventorySyncJob).not_to have_received(:perform_later).with(uninstalled_shop.id)
    end

    it 'enqueues independently across separate runs (stateless)' do
      DailySyncAllShopsJob.new.perform
      DailySyncAllShopsJob.new.perform

      expect(InventorySyncJob).to have_received(:perform_later).with(shop_a.id).twice
      expect(InventorySyncJob).to have_received(:perform_later).with(shop_b.id).twice
    end
  end

  # --------------------------------------------------------------------------
  # 6. InventorySyncJob updates synced_at atomically
  # --------------------------------------------------------------------------
  describe 'InventorySyncJob synced_at' do
    let(:graphql_response) do
      {
        products: [
          {
            'legacyResourceId' => product.shopify_product_id.to_s,
            'title' => product.title,
            'productType' => 'Gadgets',
            'vendor' => 'WidgetCo',
            'status' => 'ACTIVE',
            'variants' => {
              'nodes' => [
                {
                  'legacyResourceId' => variant.shopify_variant_id.to_s,
                  'sku' => variant.sku,
                  'title' => variant.title,
                  'price' => variant.price.to_s,
                  'inventoryItem' => {
                    'inventoryLevels' => {
                      'nodes' => [
                        {
                          'quantities' => [
                            { 'name' => 'available', 'quantity' => 50 },
                            { 'name' => 'on_hand', 'quantity' => 55 },
                            { 'name' => 'committed', 'quantity' => 5 },
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
      variant

      allow_any_instance_of(Shopify::InventoryFetcher).to receive(:fetch_all_products_with_inventory).and_return(graphql_response)
      allow_any_instance_of(Notifications::AlertSender).to receive(:create_alerts_and_notify)
    end

    it 'updates synced_at after the full pipeline completes' do
      expect(shop.synced_at).to be_nil

      ActsAsTenant.with_tenant(shop) do
        InventorySyncJob.new.perform(shop.id)
      end

      shop.reload
      expect(shop.synced_at).to be_within(5.seconds).of(Time.current)
    end

    it 'does not update synced_at if the fetcher raises' do
      allow_any_instance_of(Shopify::InventoryFetcher).to receive(:fetch_all_products_with_inventory).and_raise(
        Shopify::GraphqlClient::ShopifyApiError.new('API down')
      )

      expect do
        ActsAsTenant.with_tenant(shop) do
          InventorySyncJob.new.perform(shop.id)
        end
      end.to raise_error(Shopify::GraphqlClient::ShopifyApiError)

      shop.reload
      expect(shop.synced_at).to be_nil
    end

    it 'updates synced_at to the latest time on successive successful syncs' do
      ActsAsTenant.with_tenant(shop) do
        InventorySyncJob.new.perform(shop.id)
      end
      first_synced_at = shop.reload.synced_at

      travel_to(5.minutes.from_now) do
        ActsAsTenant.with_tenant(shop) do
          InventorySyncJob.new.perform(shop.id)
        end
      end

      shop.reload
      expect(shop.synced_at).to be > first_synced_at
    end

    it 'persists products, variants, and snapshots during sync' do
      ActsAsTenant.with_tenant(shop) do
        InventorySyncJob.new.perform(shop.id)
      end

      ActsAsTenant.with_tenant(shop) do
        expect(Product.count).to be >= 1
        expect(Variant.count).to be >= 1
        expect(InventorySnapshot.count).to be >= 1

        snapshot = InventorySnapshot.last
        expect(snapshot.available).to eq(50)
        expect(snapshot.on_hand).to eq(55)
        expect(snapshot.committed).to eq(5)
      end
    end
  end
end
