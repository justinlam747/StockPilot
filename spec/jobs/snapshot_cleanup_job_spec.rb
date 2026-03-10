require "rails_helper"

RSpec.describe SnapshotCleanupJob, type: :job do
  let(:shop) { create(:shop) }

  it "deletes old snapshots and keeps recent ones" do
    product = create(:product, shop: shop)
    variant = create(:variant, shop: shop, product: product)

    ActsAsTenant.with_tenant(shop) do
      # Old snapshot
      InventorySnapshot.create!(
        shop: shop,
        variant: variant,
        available: 5,
        on_hand: 5,
        created_at: 100.days.ago
      )
      # Recent snapshot
      InventorySnapshot.create!(
        shop: shop,
        variant: variant,
        available: 10,
        on_hand: 10,
        created_at: 1.day.ago
      )
    end

    expect { described_class.perform_now }.to change { InventorySnapshot.count }.by(-1)
    expect(InventorySnapshot.count).to eq(1)
  end
end
