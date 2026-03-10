require "rails_helper"

RSpec.describe InventorySyncJob, type: :job do
  let(:shop) { create(:shop) }

  it "calls each service in order" do
    data = { products: [], fetched_at: Time.current }

    fetcher = instance_double(Shopify::InventoryFetcher)
    persister = instance_double(Inventory::Persister)
    snapshotter = instance_double(Inventory::Snapshotter)
    detector = instance_double(Inventory::LowStockDetector)
    sender = instance_double(Notifications::AlertSender)

    expect(Shopify::InventoryFetcher).to receive(:new).with(shop).and_return(fetcher)
    expect(fetcher).to receive(:call).and_return(data)

    expect(Inventory::Persister).to receive(:new).with(shop).and_return(persister)
    expect(persister).to receive(:upsert).with(data)

    expect(Inventory::Snapshotter).to receive(:new).with(shop).and_return(snapshotter)
    expect(snapshotter).to receive(:snapshot).with(data)

    expect(Inventory::LowStockDetector).to receive(:new).with(shop).and_return(detector)
    expect(detector).to receive(:detect).and_return([])

    expect(Notifications::AlertSender).to receive(:new).with(shop).and_return(sender)
    expect(sender).to receive(:send_low_stock_alerts).with([])

    described_class.perform_now(shop.id)

    expect(shop.reload.synced_at).to be_present
  end
end
