# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Webhook pipeline', type: :request do
  let(:shop) { create(:shop) }
  let(:product) { create(:product, shop: shop, shopify_product_id: 7001, title: 'Original Title') }
  let(:secret) { 'test_webhook_secret' }

  before do
    product
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with('SHOPIFY_API_SECRET').and_return(secret)
  end

  def webhook_headers(body, topic: nil) # rubocop:disable Lint/UnusedMethodArgument
    digest = OpenSSL::HMAC.digest('sha256', secret, body)
    hmac = Base64.strict_encode64(digest)
    {
      'HTTP_X_SHOPIFY_HMAC_SHA256' => hmac,
      'X-Shopify-Shop-Domain' => shop.shop_domain,
      'CONTENT_TYPE' => 'application/json'
    }
  end

  describe 'products/update webhook' do
    it 'updates the product title' do
      body = {
        id: product.shopify_product_id,
        title: 'Updated Title',
        product_type: 'Apparel',
        vendor: 'TestCo',
        status: 'active',
        variants: []
      }.to_json

      ActsAsTenant.with_tenant(shop) do
        post '/webhooks/products_update', params: body,
                                          headers: webhook_headers(body, topic: 'products_update')
      end

      expect(response).to have_http_status(:ok)
      expect(product.reload.title).to eq('Updated Title')
    end

    it 'creates an audit log entry' do
      body = { id: product.shopify_product_id, title: 'New', variants: [] }.to_json

      expect do
        post '/webhooks/products_update', params: body,
                                          headers: webhook_headers(body, topic: 'products_update')
      end.to change(AuditLog.where(action: 'webhook_received'), :count).by(1)
    end
  end

  describe 'products/delete webhook' do
    it 'soft-deletes the product' do
      body = { id: product.shopify_product_id }.to_json

      ActsAsTenant.with_tenant(shop) do
        post '/webhooks/products_delete', params: body,
                                          headers: webhook_headers(body, topic: 'products_delete')
      end

      expect(response).to have_http_status(:ok)
      expect(product.reload.deleted_at).to be_present
    end
  end

  describe 'app/uninstalled webhook' do
    it 'marks the shop as uninstalled' do
      body = { shop_domain: shop.shop_domain }.to_json

      post '/webhooks/app_uninstalled', params: body,
                                        headers: webhook_headers(body, topic: 'app_uninstalled')

      expect(response).to have_http_status(:ok)
      expect(shop.reload.uninstalled_at).to be_present
    end
  end

  describe 'HMAC verification' do
    it 'rejects requests with invalid HMAC' do
      body = { id: 123 }.to_json
      headers = {
        'HTTP_X_SHOPIFY_HMAC_SHA256' => 'invalid_hmac',
        'X-Shopify-Shop-Domain' => shop.shop_domain,
        'CONTENT_TYPE' => 'application/json'
      }

      post '/webhooks/products_update', params: body, headers: headers
      expect(response).to have_http_status(:unauthorized)
    end

    it 'rejects requests without HMAC header' do
      body = { id: 123 }.to_json

      post '/webhooks/products_update', params: body,
                                        headers: { 'CONTENT_TYPE' => 'application/json' }
      expect(response).to have_http_status(:unauthorized)
    end
  end
end
