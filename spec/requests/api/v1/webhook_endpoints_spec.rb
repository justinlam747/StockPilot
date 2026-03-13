require "rails_helper"

RSpec.describe "Api::V1::WebhookEndpoints", type: :request do
  let(:shop) { create(:shop) }

  before do
    authenticate_shop(shop)
    ActsAsTenant.current_tenant = shop
  end

  describe "GET /api/v1/webhook_endpoints" do
    it "returns endpoints" do
      create(:webhook_endpoint, shop: shop)

      get "/api/v1/webhook_endpoints"

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["webhook_endpoints"].size).to eq(1)
    end
  end

  describe "POST /api/v1/webhook_endpoints" do
    it "creates an endpoint" do
      params = { webhook_endpoint: { url: "https://example.com/hook", event_type: "low_stock", is_active: true } }

      post "/api/v1/webhook_endpoints",
           params: params.to_json,
           headers: { "Content-Type" => "application/json" }

      expect(response).to have_http_status(:created)
    end
  end

  describe "DELETE /api/v1/webhook_endpoints/:id" do
    it "destroys an endpoint" do
      endpoint = create(:webhook_endpoint, shop: shop)

      delete "/api/v1/webhook_endpoints/#{endpoint.id}"

      expect(response).to have_http_status(:no_content)
    end
  end

  describe "GET /api/v1/webhook_endpoints/:id" do
    it "returns a specific endpoint" do
      endpoint = create(:webhook_endpoint, shop: shop, url: "https://example.com/specific", event_type: "low_stock")

      get "/api/v1/webhook_endpoints/#{endpoint.id}"

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["url"]).to eq("https://example.com/specific")
      expect(body["event_type"]).to eq("low_stock")
    end
  end

  describe "PATCH /api/v1/webhook_endpoints/:id" do
    it "updates an endpoint" do
      endpoint = create(:webhook_endpoint, shop: shop, url: "https://example.com/old")

      patch "/api/v1/webhook_endpoints/#{endpoint.id}",
            params: { webhook_endpoint: { url: "https://example.com/new" } }.to_json,
            headers: { "Content-Type" => "application/json" }

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["url"]).to eq("https://example.com/new")
      expect(endpoint.reload.url).to eq("https://example.com/new")
    end
  end

  describe "DELETE /api/v1/webhook_endpoints/:id (non-existent)" do
    it "returns 404 for a non-existent endpoint" do
      delete "/api/v1/webhook_endpoints/999999"

      expect(response).to have_http_status(:not_found)
    end
  end
end
