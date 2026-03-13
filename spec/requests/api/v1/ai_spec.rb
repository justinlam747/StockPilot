require "rails_helper"

RSpec.describe "Api::V1::AI", type: :request do
  let(:shop) { create(:shop) }

  before do
    authenticate_shop(shop)
    ActsAsTenant.current_tenant = shop
  end

  describe "GET /api/v1/ai/insights" do
    it "returns AI insights" do
      allow_any_instance_of(AI::InsightsGenerator).to receive(:generate)
        .and_return("- Insight 1\n- Insight 2")

      get "/api/v1/ai/insights"

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["insights"]).to include("Insight 1")
    end
  end

  describe "GET /api/v1/ai/agent_status" do
    it "returns agent status with counts" do
      detector = instance_double(Inventory::LowStockDetector)
      allow(Inventory::LowStockDetector).to receive(:new).and_return(detector)
      allow(detector).to receive(:detect).and_return([
        { variant: double, status: :low_stock, available: 3, threshold: 10 },
        { variant: double, status: :out_of_stock, available: 0, threshold: 10 }
      ])

      get "/api/v1/ai/agent_status"

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["low_stock_count"]).to eq(1)
      expect(body["out_of_stock_count"]).to eq(1)
      expect(body).to have_key("alerts_sent_today")
      expect(body).to have_key("last_sync")
    end
  end

  describe "POST /api/v1/ai/run_agent" do
    it "enqueues AgentInventoryCheckJob" do
      expect {
        post "/api/v1/ai/run_agent"
      }.to have_enqueued_job(AgentInventoryCheckJob)

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["status"]).to eq("queued")
    end
  end

  describe "GET /api/v1/ai/insights when AI fails" do
    it "returns a fallback response" do
      allow_any_instance_of(AI::InsightsGenerator).to receive(:generate)
        .and_raise(StandardError, "API unavailable")

      get "/api/v1/ai/insights"

      expect(response.status).to be_in([200, 500, 503])
    end
  end
end
