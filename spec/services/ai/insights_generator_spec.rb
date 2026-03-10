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
end
