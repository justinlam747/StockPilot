require "rails_helper"

RSpec.describe AI::InsightsGenerator do
  let(:shop) { create(:shop) }
  let(:generator) { described_class.new(shop) }

  before do
    ActsAsTenant.current_tenant = shop
    allow(Inventory::LowStockDetector).to receive(:new).and_return(
      instance_double(Inventory::LowStockDetector, detect: [])
    )
  end

  it "returns AI-generated insights on success" do
    mock_client = instance_double(Anthropic::Client)
    allow(Anthropic::Client).to receive(:new).and_return(mock_client)
    allow(mock_client).to receive(:messages).and_return(
      { "content" => [{ "text" => "- Insight 1\n- Insight 2\n- Insight 3" }] }
    )

    result = generator.generate
    expect(result).to include("Insight 1")
  end

  it "returns fallback string on Anthropic error" do
    allow(Anthropic::Client).to receive(:new).and_raise(Anthropic::Error.new("API down"))

    result = generator.generate
    expect(result).to eq("AI insights temporarily unavailable.")
  end

  it "passes correct metrics structure to Claude" do
    mock_client = instance_double(Anthropic::Client)
    allow(Anthropic::Client).to receive(:new).and_return(mock_client)
    allow(mock_client).to receive(:messages).and_return(
      { "content" => [{ "text" => "- All good" }] }
    )

    generator.generate

    expect(mock_client).to have_received(:messages) do |args|
      user_content = args[:messages].first[:content]
      metrics = JSON.parse(user_content.match(/\{.*\}/m)[0])
      expect(metrics).to have_key("total_skus")
      expect(metrics).to have_key("low_stock_count")
      expect(metrics).to have_key("out_of_stock_count")
      expect(metrics).to have_key("top_low_stock")
    end
  end

  it "includes actual flagged variant data in metrics" do
    product = create(:product, shop: shop)
    variant = create(:variant, shop: shop, product: product, sku: "LOW-001")
    InventorySnapshot.create!(shop: shop, variant: variant, available: 2, on_hand: 2)

    allow(Inventory::LowStockDetector).to receive(:new).and_return(
      instance_double(Inventory::LowStockDetector, detect: [
        { variant: variant, available: 2, status: :low_stock, threshold: 10 }
      ])
    )

    mock_client = instance_double(Anthropic::Client)
    allow(Anthropic::Client).to receive(:new).and_return(mock_client)
    allow(mock_client).to receive(:messages).and_return(
      { "content" => [{ "text" => "- Reorder LOW-001" }] }
    )

    generator.generate

    expect(mock_client).to have_received(:messages) do |args|
      user_content = args[:messages].first[:content]
      metrics = JSON.parse(user_content.match(/\{.*\}/m)[0])
      expect(metrics["low_stock_count"]).to eq(1)
      expect(metrics["out_of_stock_count"]).to eq(0)
      expect(metrics["top_low_stock"].first["sku"]).to eq("LOW-001")
    end
  end
end
