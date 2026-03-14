require "rails_helper"

RSpec.describe "Inventory", type: :request do
  let(:shop) { create(:shop) }

  before { login_as(shop) }

  describe "GET /inventory" do
    it "returns success" do
      get "/inventory"
      expect(response).to have_http_status(:ok)
    end

    it "filters by low stock" do
      get "/inventory?filter=low_stock", headers: { "HX-Request" => "true" }
      expect(response).to have_http_status(:ok)
    end

    it "searches by name" do
      get "/inventory?q=widget", headers: { "HX-Request" => "true" }
      expect(response).to have_http_status(:ok)
    end
  end
end
