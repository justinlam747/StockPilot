require "rails_helper"

RSpec.describe Inventory::LowStockDetector do
  let(:shop) { create(:shop, settings: { "low_stock_threshold" => 10 }) }
  let(:detector) { described_class.new(shop) }

  before do
    ActsAsTenant.current_tenant = shop
  end

  it "flags low-stock variants" do
    product = create(:product, shop: shop)
    variant = create(:variant, shop: shop, product: product)
    InventorySnapshot.create!(shop: shop, variant: variant, available: 5, on_hand: 5)

    results = detector.detect
    expect(results.size).to eq(1)
    expect(results.first[:status]).to eq(:low_stock)
    expect(results.first[:available]).to eq(5)
  end

  it "flags out-of-stock variants" do
    product = create(:product, shop: shop)
    variant = create(:variant, shop: shop, product: product)
    InventorySnapshot.create!(shop: shop, variant: variant, available: 0, on_hand: 0)

    results = detector.detect
    expect(results.size).to eq(1)
    expect(results.first[:status]).to eq(:out_of_stock)
  end

  it "does not flag ok variants" do
    product = create(:product, shop: shop)
    variant = create(:variant, shop: shop, product: product)
    InventorySnapshot.create!(shop: shop, variant: variant, available: 50, on_hand: 50)

    results = detector.detect
    expect(results).to be_empty
  end

  it "respects variant-level threshold override" do
    product = create(:product, shop: shop)
    variant = create(:variant, shop: shop, product: product, low_stock_threshold: 3)
    InventorySnapshot.create!(shop: shop, variant: variant, available: 5, on_hand: 5)

    results = detector.detect
    expect(results).to be_empty # 5 is above variant threshold of 3
  end

  it "excludes soft-deleted products" do
    product = create(:product, shop: shop, deleted_at: Time.current)
    variant = create(:variant, shop: shop, product: product)
    InventorySnapshot.create!(shop: shop, variant: variant, available: 1, on_hand: 1)

    results = detector.detect
    expect(results).to be_empty
  end
end
