require "rails_helper"

RSpec.describe "Api::V1::Reports", type: :request do
  let(:shop) { create(:shop) }

  before do
    authenticate_shop(shop)
    ActsAsTenant.current_tenant = shop
  end

  describe "GET /api/v1/reports" do
    it "returns paginated reports" do
      create(:weekly_report, shop: shop)

      get "/api/v1/reports"

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["reports"].size).to eq(1)
    end
  end

  describe "GET /api/v1/reports/:id" do
    it "returns a single report with payload" do
      report = create(:weekly_report, shop: shop)

      get "/api/v1/reports/#{report.id}"

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["payload"]).to be_present
    end
  end

  describe "POST /api/v1/reports/generate" do
    it "enqueues a weekly report job" do
      expect {
        post "/api/v1/reports/generate"
      }.to have_enqueued_job(WeeklyReportJob)

      expect(response).to have_http_status(:accepted)
    end
  end
end
