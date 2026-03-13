require "rails_helper"

RSpec.describe "GDPR Webhooks", type: :request do
  let(:shop) { create(:shop) }

  before do
    allow_any_instance_of(GdprController).to receive(:verify_request).and_return(true)
  end

  describe "POST /api/webhooks/customers_data_request" do
    it "returns 200 and logs the request" do
      body = { "shop_domain" => shop.shop_domain }.to_json

      post "/api/webhooks/customers_data_request",
           params: body,
           headers: { "Content-Type" => "application/json" }

      expect(response).to have_http_status(:ok)
    end
  end

  describe "POST /api/webhooks/customers_redact" do
    it "deletes customer records for the shop" do
      customer = Customer.create!(shop: shop, shopify_customer_id: "99999")
      body = {
        "shop_domain" => shop.shop_domain,
        "customer" => { "id" => "99999" }
      }.to_json

      post "/api/webhooks/customers_redact",
           params: body,
           headers: { "Content-Type" => "application/json" }

      expect(response).to have_http_status(:ok)
      expect(Customer.where(shopify_customer_id: "99999").count).to eq(0)
    end
  end

  describe "POST /api/webhooks/shop_redact" do
    it "destroys the shop and all its data" do
      body = { "shop_domain" => shop.shop_domain }.to_json

      post "/api/webhooks/shop_redact",
           params: body,
           headers: { "Content-Type" => "application/json" }

      expect(response).to have_http_status(:ok)
      expect(Shop.find_by(id: shop.id)).to be_nil
    end
  end

  describe "POST /api/webhooks/customers_redact with non-existent shop" do
    it "still returns 200 for an unknown shop domain" do
      body = {
        "shop_domain" => "nonexistent-shop.myshopify.com",
        "customer" => { "id" => "12345" }
      }.to_json

      post "/api/webhooks/customers_redact",
           params: body,
           headers: { "Content-Type" => "application/json" }

      expect(response).to have_http_status(:ok)
    end
  end

  describe "POST /api/webhooks/shop_redact with non-existent shop" do
    it "still returns 200 for an unknown shop domain" do
      body = { "shop_domain" => "nonexistent-shop.myshopify.com" }.to_json

      post "/api/webhooks/shop_redact",
           params: body,
           headers: { "Content-Type" => "application/json" }

      expect(response).to have_http_status(:ok)
    end
  end
end
