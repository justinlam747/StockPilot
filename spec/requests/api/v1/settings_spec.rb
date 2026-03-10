require "rails_helper"

RSpec.describe "Api::V1::Settings", type: :request do
  let(:shop) { create(:shop) }

  before do
    authenticate_shop(shop)
    ActsAsTenant.current_tenant = shop
  end

  describe "GET /api/v1/settings" do
    it "returns current shop settings" do
      get "/api/v1/settings"

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["low_stock_threshold"]).to eq(10)
      expect(body["timezone"]).to eq("America/Toronto")
    end
  end

  describe "PATCH /api/v1/settings" do
    it "updates settings" do
      patch "/api/v1/settings",
            params: { settings: { low_stock_threshold: 20, alert_email: "new@example.com" } }.to_json,
            headers: { "Content-Type" => "application/json" }

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["low_stock_threshold"]).to eq(20)
      expect(body["alert_email"]).to eq("new@example.com")
    end
  end
end
