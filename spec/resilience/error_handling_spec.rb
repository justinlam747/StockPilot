# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Error handling and resilience', type: :model do
  let(:shop) do
    create(:shop, settings: {
             'low_stock_threshold' => 10,
             'timezone' => 'America/Toronto',
             'alert_email' => 'merchant@example.com'
           })
  end

  before do
    ActsAsTenant.current_tenant = shop
  end

  # ---------------------------------------------------------------------------
  # 1. Shopify API failures in InventoryFetcher
  # ---------------------------------------------------------------------------
  describe 'Shopify::InventoryFetcher error handling' do
    let(:fetcher) { Shopify::InventoryFetcher.new(shop) }

    it 'propagates ShopifyThrottledError after retries exhausted' do
      client = instance_double(Shopify::GraphqlClient)
      allow(Shopify::GraphqlClient).to receive(:new).with(shop).and_return(client)
      allow(client).to receive(:paginate).and_raise(
        Shopify::GraphqlClient::ShopifyThrottledError, 'Rate limited by Shopify'
      )

      expect { fetcher.fetch_all_products_with_inventory }.to raise_error(
        Shopify::GraphqlClient::ShopifyThrottledError, /Rate limited/
      )
    end

    it 'propagates ShopifyApiError for non-throttle errors' do
      client = instance_double(Shopify::GraphqlClient)
      allow(Shopify::GraphqlClient).to receive(:new).with(shop).and_return(client)
      allow(client).to receive(:paginate).and_raise(
        Shopify::GraphqlClient::ShopifyApiError, 'Internal error'
      )

      expect { fetcher.fetch_all_products_with_inventory }.to raise_error(
        Shopify::GraphqlClient::ShopifyApiError, /Internal error/
      )
    end
  end

  # ---------------------------------------------------------------------------
  # 2. Health check degradation
  # ---------------------------------------------------------------------------
  describe 'Health check resilience', type: :request do
    it 'returns degraded when database is down' do
      allow(ActiveRecord::Base.connection).to receive(:execute).and_raise(
        ActiveRecord::ConnectionNotEstablished, 'connection refused'
      )

      get '/health'

      expect(response).to have_http_status(:service_unavailable)
      body = JSON.parse(response.body)
      expect(body['status']).to eq('degraded')
      expect(body['error']).to include('connection refused')
    end

    it 'returns degraded when Redis is down' do
      redis_double = instance_double(Redis)
      allow(Redis).to receive(:new).and_return(redis_double)
      allow(redis_double).to receive(:ping).and_raise(Redis::CannotConnectError, 'connection refused')

      get '/health'

      expect(response).to have_http_status(:service_unavailable)
      body = JSON.parse(response.body)
      expect(body['status']).to eq('degraded')
    end

    it 'returns degraded when both Redis and DB are down' do
      allow(ActiveRecord::Base.connection).to receive(:execute).and_raise(
        ActiveRecord::ConnectionNotEstablished, 'DB down'
      )

      get '/health'

      expect(response).to have_http_status(:service_unavailable)
      body = JSON.parse(response.body)
      expect(body['status']).to eq('degraded')
      expect(body['error']).to include('DB down')
    end
  end

end
