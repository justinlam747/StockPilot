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

  describe "PATCH /api/v1/settings (partial update)" do
    it "updates only the timezone while preserving other settings" do
      patch "/api/v1/settings",
            params: { settings: { timezone: "America/New_York" } }.to_json,
            headers: { "Content-Type" => "application/json" }

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["timezone"]).to eq("America/New_York")
      expect(body["low_stock_threshold"]).to eq(10)
    end
  end

  describe "PATCH /api/v1/settings (non-allowed keys)" do
    it "rejects keys that are not in the allowed list" do
      patch "/api/v1/settings",
            params: { settings: { admin: true, low_stock_threshold: 15 } }.to_json,
            headers: { "Content-Type" => "application/json" }

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["low_stock_threshold"]).to eq(15)
      expect(shop.reload.settings).not_to have_key("admin")
    end
  end

  describe "GET /api/v1/settings with custom values" do
    it "returns previously customized settings" do
      shop.update!(settings: shop.settings.merge(
        "low_stock_threshold" => 50,
        "alert_email" => "custom@example.com",
        "timezone" => "Europe/London",
        "weekly_report_day" => "friday"
      ))

      get "/api/v1/settings"

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["low_stock_threshold"]).to eq(50)
      expect(body["alert_email"]).to eq("custom@example.com")
      expect(body["timezone"]).to eq("Europe/London")
      expect(body["weekly_report_day"]).to eq("friday")
    end
  end
end
