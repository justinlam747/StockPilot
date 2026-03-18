# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Webhook HMAC verification', type: :request do
  let(:secret) { ENV.fetch('SHOPIFY_API_SECRET', 'test-secret') }

  it 'accepts valid HMAC' do
    body = { topic: 'products/update' }.to_json
    digest = OpenSSL::HMAC.digest('sha256', secret, body)
    hmac = Base64.strict_encode64(digest)
    post '/webhooks/products_update', params: body,
                                      headers: { 'HTTP_X_SHOPIFY_HMAC_SHA256' => hmac, 'CONTENT_TYPE' => 'application/json' }
    expect(response).to have_http_status(:ok)
  end

  it 'rejects invalid HMAC' do
    post '/webhooks/products_update', params: '{}',
                                      headers: { 'HTTP_X_SHOPIFY_HMAC_SHA256' => 'bad', 'CONTENT_TYPE' => 'application/json' }
    expect(response).to have_http_status(:unauthorized)
  end

  it 'rejects missing HMAC' do
    post '/webhooks/products_update', params: '{}', headers: { 'CONTENT_TYPE' => 'application/json' }
    expect(response).to have_http_status(:unauthorized)
  end
end
