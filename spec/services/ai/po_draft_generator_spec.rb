require "rails_helper"

RSpec.describe AI::PoDraftGenerator do
  let(:shop) { create(:shop) }
  let(:supplier) { create(:supplier, shop: shop, name: "ACME Corp", email: "orders@acme.com") }
  let(:product) { create(:product, shop: shop, title: "Widget") }
  let(:variant) { create(:variant, shop: shop, product: product, sku: "WDG-001", title: "Small") }
  let(:generator) { described_class.new }

  let(:po) { create(:purchase_order, shop: shop, supplier: supplier) }
  let(:line_items) do
    [PurchaseOrderLineItem.create!(
      purchase_order: po,
      variant: variant,
      sku: "WDG-001",
      quantity_ordered: 50,
      unit_price: 9.99
    )]
  end

  it "returns AI-generated draft on success" do
    mock_client = instance_double(Anthropic::Client)
    allow(Anthropic::Client).to receive(:new).and_return(mock_client)
    allow(mock_client).to receive(:messages).and_return(
      { "content" => [{ "text" => "Dear ACME Corp,\n\nPlease process the following order..." }] }
    )

    result = generator.generate(supplier: supplier, line_items: line_items, shop: shop)
    expect(result).to include("ACME Corp")
  end

  it "returns plain-text fallback on API failure" do
    allow(Anthropic::Client).to receive(:new).and_raise(Anthropic::Error.new("API down"))

    result = generator.generate(supplier: supplier, line_items: line_items, shop: shop)
    expect(result).to include("Dear ACME Corp")
    expect(result).to include("WDG-001")
  end

  it "passes correct prompt with supplier name, items, and shop domain" do
    mock_client = instance_double(Anthropic::Client)
    allow(Anthropic::Client).to receive(:new).and_return(mock_client)
    allow(mock_client).to receive(:messages).and_return(
      { "content" => [{ "text" => "Draft PO email" }] }
    )

    generator.generate(supplier: supplier, line_items: line_items, shop: shop)

    expect(mock_client).to have_received(:messages) do |args|
      prompt_content = args[:messages].first[:content]
      expect(prompt_content).to include("ACME Corp")
      expect(prompt_content).to include("orders@acme.com")
      expect(prompt_content).to include(shop.shop_domain)
      expect(prompt_content).to include("WDG-001")
      expect(prompt_content).to include("50")
    end
  end

  it "fallback includes all line item SKUs for multiple items" do
    product2 = create(:product, shop: shop, title: "Gadget")
    variant2 = create(:variant, shop: shop, product: product2, sku: "GDG-002", title: "Large")
    line_item2 = PurchaseOrderLineItem.create!(
      purchase_order: po,
      variant: variant2,
      sku: "GDG-002",
      quantity_ordered: 25,
      unit_price: 19.99
    )

    allow(Anthropic::Client).to receive(:new).and_raise(Anthropic::Error.new("API down"))

    result = generator.generate(supplier: supplier, line_items: line_items + [line_item2], shop: shop)
    expect(result).to include("WDG-001")
    expect(result).to include("GDG-002")
    expect(result).to include("Dear ACME Corp")
  end
end
