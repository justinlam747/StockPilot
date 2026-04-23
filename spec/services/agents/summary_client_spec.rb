# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Agents::SummaryClient do
  let(:shop) { create(:shop) }
  let(:context) do
    {
      'flagged_count' => 3,
      'counts' => { 'low_stock' => 2, 'out_of_stock' => 1, 'supplierless' => 4 },
      'top_items' => [
        { 'sku' => 'SKU-1', 'available' => 0 },
        { 'sku' => 'SKU-2', 'available' => 2 }
      ],
      'supplier_recommendations' => [
        { 'supplier_name' => 'Acme', 'item_count' => 2 }
      ],
      'supplierless_items' => [
        { 'sku' => 'SKU-3', 'available' => 1 }
      ],
      'correction' => 'Ignore accessories'
    }
  end

  it 'returns a deterministic summary when no provider is configured' do
    client = described_class.new(shop)
    allow(client).to receive(:provider_name).and_return('fallback')

    summary = client.generate(context)

    expect(summary).to include(shop.shop_domain)
    expect(summary).to include('3 flagged SKU')
    expect(summary).to include('4 flagged SKU')
    expect(summary).to include('Operator correction applied')
  end

  it 'falls back when an external provider errors' do
    http_client = class_double(HTTParty)
    client = described_class.new(shop, http_client: http_client)
    allow(client).to receive(:provider_name).and_return('openai')
    allow(http_client).to receive(:post).and_raise(Timeout::Error)

    summary = client.generate(context)

    expect(summary).to include('Most urgent items')
  end
end
