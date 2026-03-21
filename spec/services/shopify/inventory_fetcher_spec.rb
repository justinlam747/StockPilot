# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Shopify::InventoryFetcher do
  include ActiveSupport::Testing::TimeHelpers

  let(:shop) { create(:shop) }
  let(:mock_client) { instance_double(Shopify::GraphqlClient) }

  before do
    allow(Shopify::GraphqlClient).to receive(:new).with(shop).and_return(mock_client)
  end

  describe '#call' do
    let(:fetcher) { described_class.new(shop) }
    let(:products_data) do
      [
        {
          'id' => 'gid://shopify/Product/1001',
          'title' => 'Test Product',
          'variants' => { 'nodes' => [] }
        }
      ]
    end

    it 'calls paginate with the PRODUCTS_QUERY and correct connection_path' do
      allow(mock_client).to receive(:paginate).and_return(products_data)

      fetcher.call

      expect(mock_client).to have_received(:paginate).with(
        Shopify::InventoryFetcher::PRODUCTS_QUERY,
        connection_path: ['products']
      )
    end

    it 'returns a hash with :products and :fetched_at' do
      allow(mock_client).to receive(:paginate).and_return(products_data)

      freeze_time do
        result = fetcher.call

        expect(result).to be_a(Hash)
        expect(result[:products]).to eq(products_data)
        expect(result[:fetched_at]).to be_within(1.second).of(Time.current)
      end
    end

    it 'returns empty products array when no products exist' do
      allow(mock_client).to receive(:paginate).and_return([])

      result = fetcher.call

      expect(result[:products]).to eq([])
      expect(result[:fetched_at]).to be_present
    end

    it 'returns multiple products with nested variants' do
      multi_products = [
        {
          'id' => 'gid://shopify/Product/1001',
          'title' => 'Widget A',
          'variants' => {
            'nodes' => [
              { 'id' => 'gid://shopify/ProductVariant/2001', 'sku' => 'WIDGET-A-S' },
              { 'id' => 'gid://shopify/ProductVariant/2002', 'sku' => 'WIDGET-A-M' }
            ]
          }
        },
        {
          'id' => 'gid://shopify/Product/1002',
          'title' => 'Widget B',
          'variants' => {
            'nodes' => [
              { 'id' => 'gid://shopify/ProductVariant/2003', 'sku' => 'WIDGET-B-S' }
            ]
          }
        }
      ]
      allow(mock_client).to receive(:paginate).and_return(multi_products)

      result = fetcher.call

      expect(result[:products].size).to eq(2)
      expect(result[:products].first['variants']['nodes'].size).to eq(2)
    end

    it 'propagates errors from the GraphQL client' do
      allow(mock_client).to receive(:paginate)
        .and_raise(Shopify::GraphqlClient::ShopifyApiError, 'API failure')

      expect { fetcher.call }.to raise_error(Shopify::GraphqlClient::ShopifyApiError, 'API failure')
    end
  end
end
