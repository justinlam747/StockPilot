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
end
