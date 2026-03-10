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
end
