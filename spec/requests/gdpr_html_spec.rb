# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'GDPR endpoints' do
  let(:shop) { create(:shop) }
  let(:secret) { ENV.fetch('SHOPIFY_API_SECRET', 'test-secret') }

  def shopify_hmac(body)
    digest = OpenSSL::HMAC.digest('sha256', secret, body)
    Base64.strict_encode64(digest)
  end

  describe 'POST /gdpr/shop_redact' do
    it 'queues shop data deletion' do
      body = { shop_domain: shop.shop_domain }.to_json
      headers = {
        'HTTP_X_SHOPIFY_HMAC_SHA256' => shopify_hmac(body),
        'CONTENT_TYPE' => 'application/json'
      }
      expect do
        post '/gdpr/shop_redact', params: body, headers: headers
      end.to have_enqueued_job(GdprShopRedactJob).with(shop.id)
      expect(response).to have_http_status(:ok)
    end

    it 'rejects requests without valid HMAC' do
      body = { shop_domain: shop.shop_domain }.to_json
      headers = { 'HTTP_X_SHOPIFY_HMAC_SHA256' => 'invalid', 'CONTENT_TYPE' => 'application/json' }
      post '/gdpr/shop_redact', params: body, headers: headers
      expect(response).to have_http_status(:unauthorized)
    end

    it 'creates an audit log' do
      body = { shop_domain: shop.shop_domain }.to_json
      headers = {
        'HTTP_X_SHOPIFY_HMAC_SHA256' => shopify_hmac(body),
        'CONTENT_TYPE' => 'application/json'
      }
      expect do
        post '/gdpr/shop_redact', params: body, headers: headers
      end.to change(AuditLog.where(action: 'gdpr_shop_redact'), :count).by(1)
    end
  end

  describe 'POST /gdpr/customers_redact' do
    it 'queues customer data deletion' do
      body = { shop_domain: shop.shop_domain, customer: { id: 123 } }.to_json
      headers = {
        'HTTP_X_SHOPIFY_HMAC_SHA256' => shopify_hmac(body),
        'CONTENT_TYPE' => 'application/json'
      }
      expect do
        post '/gdpr/customers_redact', params: body, headers: headers
      end.to have_enqueued_job(GdprCustomerRedactJob).with(shop.id, 123)
      expect(response).to have_http_status(:ok)
    end
  end
end
