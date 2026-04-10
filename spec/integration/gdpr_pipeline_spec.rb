# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'GDPR compliance pipeline' do
  let(:shop) { create(:shop) }
  let(:secret) { 'test_webhook_secret' }

  before do
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with('SHOPIFY_API_SECRET').and_return(secret)
  end

  def gdpr_headers(body)
    digest = OpenSSL::HMAC.digest('sha256', secret, body)
    hmac = Base64.strict_encode64(digest)
    {
      'HTTP_X_SHOPIFY_HMAC_SHA256' => hmac,
      'CONTENT_TYPE' => 'application/json'
    }
  end

  describe 'POST /gdpr/customers_data_request' do
    it 'returns 200 and enqueues the data export job' do
      body = { shop_domain: shop.shop_domain, customer: { id: 12_345 } }.to_json

      post '/gdpr/customers_data_request', params: body, headers: gdpr_headers(body)
      expect(response).to have_http_status(:ok)
    end

    it 'creates an audit log' do
      body = { shop_domain: shop.shop_domain, customer: { id: 12_345 } }.to_json

      expect do
        post '/gdpr/customers_data_request', params: body, headers: gdpr_headers(body)
      end.to change(AuditLog.where(action: 'gdpr_customer_data_request'), :count).by(1)
    end

    it 'returns 404 for unknown shop' do
      body = { shop_domain: 'nonexistent.myshopify.com', customer: { id: 1 } }.to_json
      post '/gdpr/customers_data_request', params: body, headers: gdpr_headers(body)
      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'POST /gdpr/customers_redact' do
    it 'returns 200 and enqueues the redact job' do
      body = { shop_domain: shop.shop_domain, customer: { id: 12_345 } }.to_json

      post '/gdpr/customers_redact', params: body, headers: gdpr_headers(body)
      expect(response).to have_http_status(:ok)
    end
  end

  describe 'POST /gdpr/shop_redact' do
    it 'returns 200 and enqueues the shop redact job' do
      body = { shop_domain: shop.shop_domain }.to_json

      post '/gdpr/shop_redact', params: body, headers: gdpr_headers(body)
      expect(response).to have_http_status(:ok)
    end

    it 'creates an audit log' do
      body = { shop_domain: shop.shop_domain }.to_json

      expect do
        post '/gdpr/shop_redact', params: body, headers: gdpr_headers(body)
      end.to change(AuditLog.where(action: 'gdpr_shop_redact'), :count).by(1)
    end
  end

  describe 'HMAC verification on GDPR endpoints' do
    it 'rejects requests with invalid HMAC' do
      body = { shop_domain: shop.shop_domain }.to_json
      headers = { 'HTTP_X_SHOPIFY_HMAC_SHA256' => 'invalid', 'CONTENT_TYPE' => 'application/json' }

      post '/gdpr/shop_redact', params: body, headers: headers
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'full shop redaction flow' do
    it 'deletes all shop data when the job runs' do
      ActsAsTenant.with_tenant(shop) do
        product = create(:product, shop: shop)
        variant = create(:variant, shop: shop, product: product)
        create(:supplier, shop: shop)
        create(:alert, shop: shop, variant: variant)
        create(:inventory_snapshot, shop: shop, variant: variant)
      end

      GdprShopRedactJob.new.perform(shop.id)

      expect(Shop.find_by(id: shop.id)).to be_nil
      expect(Product.where(shop_id: shop.id).count).to eq(0)
      expect(Variant.where(shop_id: shop.id).count).to eq(0)
      expect(Supplier.where(shop_id: shop.id).count).to eq(0)
    end
  end
end
