# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Shopify::GraphqlClient do
  let(:shop) { create(:shop) }
  let(:client) { described_class.new(shop) }

  before do
    allow(ShopifyAPI::Clients::Graphql::Admin).to receive(:new).and_return(mock_gql_client)
  end

  let(:mock_gql_client) { instance_double(ShopifyAPI::Clients::Graphql::Admin) }

  describe '#query' do
    it 'returns data on success' do
      response = double(body: { 'data' => { 'products' => [] } })
      allow(mock_gql_client).to receive(:query).and_return(response)

      result = client.query('{ products { nodes { id } } }')
      expect(result).to eq({ 'products' => [] })
    end

    it 'retries on throttle then raises' do
      error_response = double(body: {
                                'errors' => [{ 'message' => 'Throttled', 'extensions' => { 'code' => 'THROTTLED' } }]
                              })
      allow(mock_gql_client).to receive(:query).and_return(error_response)
      allow(client).to receive(:sleep)

      expect do
        client.query('{ products { nodes { id } } }')
      end.to raise_error(Shopify::GraphqlClient::ShopifyThrottledError)
    end

    it 'raises ShopifyApiError on non-throttle errors' do
      error_response = double(body: {
                                'errors' => [{ 'message' => 'Something broke',
                                               'extensions' => { 'code' => 'INTERNAL_ERROR' } }]
                              })
      allow(mock_gql_client).to receive(:query).and_return(error_response)

      expect do
        client.query('{ products { nodes { id } } }')
      end.to raise_error(Shopify::GraphqlClient::ShopifyApiError, 'Something broke')
    end

    it 'retries exactly MAX_RETRIES times on throttle before raising' do
      error_response = double(body: {
                                'errors' => [{ 'message' => 'Throttled', 'extensions' => { 'code' => 'THROTTLED' } }]
                              })
      allow(mock_gql_client).to receive(:query).and_return(error_response)
      allow(client).to receive(:sleep)

      expect do
        client.query('{ products { nodes { id } } }')
      end.to raise_error(Shopify::GraphqlClient::ShopifyThrottledError)

      # Initial call + MAX_RETRIES retries = 4 total calls
      expect(mock_gql_client).to have_received(:query).exactly(Shopify::GraphqlClient::MAX_RETRIES + 1).times
    end

    it 'returns all error messages when multiple errors are present' do
      error_response = double(body: {
                                'errors' => [
                                  { 'message' => 'Field not found', 'extensions' => { 'code' => 'FIELD_ERROR' } },
                                  { 'message' => 'Invalid argument', 'extensions' => { 'code' => 'ARGUMENT_ERROR' } }
                                ]
                              })
      allow(mock_gql_client).to receive(:query).and_return(error_response)

      expect do
        client.query('{ products { nodes { id } } }')
      end.to raise_error(Shopify::GraphqlClient::ShopifyApiError, 'Field not found, Invalid argument')
    end
  end

  describe '#paginate' do
    it 'collects all nodes across multiple pages' do
      page1_response = double(body: {
                                'data' => {
                                  'products' => {
                                    'nodes' => [{ 'id' => '1' }, { 'id' => '2' }],
                                    'pageInfo' => { 'hasNextPage' => true, 'endCursor' => 'cursor_abc' }
                                  }
                                }
                              })
      page2_response = double(body: {
                                'data' => {
                                  'products' => {
                                    'nodes' => [{ 'id' => '3' }],
                                    'pageInfo' => { 'hasNextPage' => false, 'endCursor' => 'cursor_def' }
                                  }
                                }
                              })
      allow(mock_gql_client).to receive(:query).and_return(page1_response, page2_response)

      results = client.paginate('{ products(first: 2, after: $cursor) { nodes { id } pageInfo { hasNextPage endCursor } } }',
                                variables: {},
                                connection_path: ['products'])

      expect(results).to eq([{ 'id' => '1' }, { 'id' => '2' }, { 'id' => '3' }])
      expect(mock_gql_client).to have_received(:query).twice
    end

    it 'stops when hasNextPage is false on the first page' do
      response = double(body: {
                          'data' => {
                            'products' => {
                              'nodes' => [{ 'id' => '1' }],
                              'pageInfo' => { 'hasNextPage' => false, 'endCursor' => nil }
                            }
                          }
                        })
      allow(mock_gql_client).to receive(:query).and_return(response)

      results = client.paginate('query', variables: {}, connection_path: ['products'])

      expect(results).to eq([{ 'id' => '1' }])
      expect(mock_gql_client).to have_received(:query).once
    end
  end
end
