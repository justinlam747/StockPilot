require "rails_helper"

RSpec.describe "Api::V1::Customers", type: :request do
  let(:shop) { create(:shop) }

  before do
    authenticate_shop(shop)
    ActsAsTenant.current_tenant = shop
  end

  describe "GET /api/v1/customers" do
    it "returns an empty array" do
      get "/api/v1/customers"

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)).to eq([])
    end
  end

  describe "GET /api/v1/customers/:id" do
    it "returns an empty object" do
      get "/api/v1/customers/1"

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)).to eq({})
    end
  end
end
