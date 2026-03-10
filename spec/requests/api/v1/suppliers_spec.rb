require "rails_helper"

RSpec.describe "Api::V1::Suppliers", type: :request do
  let(:shop) { create(:shop) }

  before do
    authenticate_shop(shop)
    ActsAsTenant.current_tenant = shop
  end

  describe "GET /api/v1/suppliers" do
    it "returns paginated suppliers" do
      create(:supplier, shop: shop, name: "ACME")

      get "/api/v1/suppliers"

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["suppliers"].size).to eq(1)
    end
  end

  describe "POST /api/v1/suppliers" do
    it "creates a supplier" do
      params = { supplier: { name: "New Supplier", email: "ns@example.com", lead_time_days: 7 } }

      post "/api/v1/suppliers",
           params: params.to_json,
           headers: { "Content-Type" => "application/json" }

      expect(response).to have_http_status(:created)
      expect(Supplier.last.name).to eq("New Supplier")
    end
  end

  describe "PATCH /api/v1/suppliers/:id" do
    it "updates a supplier" do
      supplier = create(:supplier, shop: shop, name: "Old Name")

      patch "/api/v1/suppliers/#{supplier.id}",
            params: { supplier: { name: "New Name" } }.to_json,
            headers: { "Content-Type" => "application/json" }

      expect(response).to have_http_status(:ok)
      expect(supplier.reload.name).to eq("New Name")
    end
  end

  describe "DELETE /api/v1/suppliers/:id" do
    it "destroys a supplier" do
      supplier = create(:supplier, shop: shop)

      delete "/api/v1/suppliers/#{supplier.id}"

      expect(response).to have_http_status(:no_content)
      expect(Supplier.find_by(id: supplier.id)).to be_nil
    end
  end
end
