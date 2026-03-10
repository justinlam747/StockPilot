require "rails_helper"

RSpec.describe "Api::V1::Shop", type: :request do
  let(:shop) { create(:shop) }

  before do
    authenticate_shop(shop)
    ActsAsTenant.current_tenant = shop
    allow(Inventory::LowStockDetector).to receive(:new).and_return(
      instance_double(Inventory::LowStockDetector, detect: [])
    )
  end

  describe "GET /api/v1/shop" do
    it "returns dashboard data" do
      get "/api/v1/shop"

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body).to have_key("total_skus")
      expect(body).to have_key("low_stock_count")
      expect(body).to have_key("out_of_stock_count")
      expect(body).to have_key("low_stock_items")
    end
  end
end
