# frozen_string_literal: true

require 'rails_helper'

RSpec.describe InventorySyncJob, type: :job do
  let(:shop) { create(:shop) }

  it 'calls each service in order' do
    data = { products: [], fetched_at: Time.current }

    fetcher = instance_double(Shopify::InventoryFetcher)
    persister = instance_double(Inventory::Persister)
    snapshotter = instance_double(Inventory::Snapshotter)
    detector = instance_double(Inventory::LowStockDetector)
    sender = instance_double(Notifications::AlertSender)

    expect(Shopify::InventoryFetcher).to receive(:new).with(shop).and_return(fetcher)
    expect(fetcher).to receive(:fetch_all_products_with_inventory).and_return(data)

    expect(Inventory::Persister).to receive(:new).with(shop).and_return(persister)
    expect(persister).to receive(:upsert).with(data)

    expect(Inventory::Snapshotter).to receive(:new).with(shop).and_return(snapshotter)
    expect(snapshotter).to receive(:create_snapshots_from_shopify_data).with(data)

    expect(Inventory::LowStockDetector).to receive(:new).with(shop).at_least(:once).and_return(detector)
    expect(detector).to receive(:detect).at_least(:once).and_return([])

    expect(Notifications::AlertSender).to receive(:new).with(shop).and_return(sender)
    expect(sender).to receive(:create_alerts_and_notify).with([])

    described_class.perform_now(shop.id)

    expect(shop.reload.synced_at).to be_present
  end
end
