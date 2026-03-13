require "rails_helper"

RSpec.describe "Api::V1::Alerts", type: :request do
  let(:shop) { create(:shop) }

  before do
    authenticate_shop(shop)
    ActsAsTenant.current_tenant = shop
  end

  describe "GET /api/v1/alerts" do
    it "returns paginated alerts" do
      product = create(:product, shop: shop)
      variant = create(:variant, shop: shop, product: product)
      create(:alert, shop: shop, variant: variant)

      get "/api/v1/alerts"

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["alerts"].size).to eq(1)
    end
  end

  describe "PATCH /api/v1/alerts/:id" do
    it "updates alert status" do
      product = create(:product, shop: shop)
      variant = create(:variant, shop: shop, product: product)
      alert = create(:alert, shop: shop, variant: variant, status: "active")

      patch "/api/v1/alerts/#{alert.id}",
            params: { alert: { status: "acknowledged" } }.to_json,
            headers: { "Content-Type" => "application/json" }

      expect(response).to have_http_status(:ok)
      expect(alert.reload.status).to eq("acknowledged")
    end
  end

  describe "GET /api/v1/alerts with multiple alerts" do
    it "returns alerts ordered by triggered_at desc" do
      product = create(:product, shop: shop)
      variant = create(:variant, shop: shop, product: product)
      older_alert = create(:alert, shop: shop, variant: variant, triggered_at: 2.days.ago)
      newer_alert = create(:alert, shop: shop, variant: variant, triggered_at: 1.hour.ago)

      get "/api/v1/alerts"

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      ids = body["alerts"].map { |a| a["id"] }
      expect(ids).to eq([newer_alert.id, older_alert.id])
    end
  end

  describe "PATCH /api/v1/alerts/:id (non-existent)" do
    it "returns 404 for a non-existent alert" do
      patch "/api/v1/alerts/999999",
            params: { alert: { status: "acknowledged" } }.to_json,
            headers: { "Content-Type" => "application/json" }

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "GET /api/v1/alerts (empty)" do
    it "returns an empty list when no alerts exist" do
      get "/api/v1/alerts"

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["alerts"]).to eq([])
      expect(body["meta"]["total_count"]).to eq(0)
    end
  end
end
