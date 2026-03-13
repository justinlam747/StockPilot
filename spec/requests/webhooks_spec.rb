require "rails_helper"

RSpec.describe "Webhooks", type: :request do
  let(:shop) { create(:shop) }
  let(:secret) { ENV.fetch("SHOPIFY_API_SECRET", "test_secret") }

  def hmac_header(body)
    digest = OpenSSL::HMAC.digest("sha256", secret, body)
    Base64.strict_encode64(digest)
  end

  before do
    allow(ShopifyApp.configuration).to receive(:secret).and_return(secret)
    # Skip HMAC verification in tests by stubbing
    allow_any_instance_of(WebhooksController).to receive(:verify_request).and_return(true)
  end

  describe "POST /api/webhooks/app_uninstalled" do
    it "marks the shop as uninstalled" do
      body = { "id" => shop.id }.to_json

      post "/api/webhooks/app_uninstalled",
           params: body,
           headers: {
             "Content-Type" => "application/json",
             "X-Shopify-Shop-Domain" => shop.shop_domain,
             "X-Shopify-Hmac-SHA256" => hmac_header(body)
           }

      expect(response).to have_http_status(:ok)
      expect(shop.reload.uninstalled_at).to be_present
    end
  end

  describe "POST /api/webhooks/products_delete" do
    it "soft-deletes the product" do
      product = create(:product, shop: shop, shopify_product_id: "12345")
      body = { "id" => 12345 }.to_json

      post "/api/webhooks/products_delete",
           params: body,
           headers: {
             "Content-Type" => "application/json",
             "X-Shopify-Shop-Domain" => shop.shop_domain,
             "X-Shopify-Hmac-SHA256" => hmac_header(body)
           }

      expect(response).to have_http_status(:ok)
      expect(product.reload.deleted_at).to be_present
    end
  end

  describe "POST /api/webhooks/products_update" do
    it "calls the Persister to upsert product data" do
      persister = instance_double(Inventory::Persister)
      allow(Inventory::Persister).to receive(:new).with(shop).and_return(persister)
      allow(persister).to receive(:upsert_single_product)

      body = { "id" => 67890, "title" => "Updated Product" }.to_json

      post "/api/webhooks/products_update",
           params: body,
           headers: {
             "Content-Type" => "application/json",
             "X-Shopify-Shop-Domain" => shop.shop_domain,
             "X-Shopify-Hmac-SHA256" => hmac_header(body)
           }

      expect(response).to have_http_status(:ok)
      expect(persister).to have_received(:upsert_single_product)
    end
  end

  describe "POST /api/webhooks/:topic (unhandled topic)" do
    it "returns 200 and logs a warning for unhandled topics" do
      body = { "data" => "test" }.to_json

      allow(Rails.logger).to receive(:warn)

      post "/api/webhooks/some_unknown_topic",
           params: body,
           headers: {
             "Content-Type" => "application/json",
             "X-Shopify-Shop-Domain" => shop.shop_domain,
             "X-Shopify-Hmac-SHA256" => hmac_header(body)
           }

      expect(response).to have_http_status(:ok)
      expect(Rails.logger).to have_received(:warn).with(/[Uu]nhandled topic/)
    end
  end
end
