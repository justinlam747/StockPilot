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

  describe "GET /api/v1/suppliers (empty)" do
    it "returns an empty array when no suppliers exist" do
      get "/api/v1/suppliers"

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["suppliers"]).to eq([])
      expect(body["meta"]["total_count"]).to eq(0)
    end
  end

  describe "POST /api/v1/suppliers with missing params" do
    it "returns 422 when required params are missing" do
      params = { supplier: { email: "no-name@example.com" } }

      post "/api/v1/suppliers",
           params: params.to_json,
           headers: { "Content-Type" => "application/json" }

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe "GET /api/v1/suppliers/:id" do
    it "returns a specific supplier" do
      supplier = create(:supplier, shop: shop, name: "Specific Supplier", email: "specific@example.com")

      get "/api/v1/suppliers/#{supplier.id}"

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["name"]).to eq("Specific Supplier")
      expect(body["email"]).to eq("specific@example.com")
    end
  end

  describe "PATCH /api/v1/suppliers/:id (non-existent)" do
    it "returns 404 for a non-existent supplier" do
      patch "/api/v1/suppliers/999999",
            params: { supplier: { name: "Ghost" } }.to_json,
            headers: { "Content-Type" => "application/json" }

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "GET /api/v1/suppliers with pagination" do
    it "respects the per_page param" do
      create_list(:supplier, 5, shop: shop)

      get "/api/v1/suppliers", params: { per_page: 2 }

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["suppliers"].size).to eq(2)
      expect(body["meta"]["total_count"]).to eq(5)
      expect(body["meta"]["total_pages"]).to eq(3)
      expect(body["meta"]["per_page"]).to eq(2)
    end
  end
end
