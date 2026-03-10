require "rails_helper"

RSpec.describe "Api::V1::Products", type: :request do
  let(:shop) { create(:shop) }

  before do
    authenticate_shop(shop)
    ActsAsTenant.current_tenant = shop
  end

  describe "GET /api/v1/products" do
    it "returns paginated products" do
      create_list(:product, 3, shop: shop)

      get "/api/v1/products"

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["products"].size).to eq(3)
      expect(body["meta"]["current_page"]).to eq(1)
      expect(body["meta"]["total_count"]).to eq(3)
    end

    it "excludes soft-deleted products" do
      create(:product, shop: shop)
      create(:product, shop: shop, deleted_at: Time.current)

      get "/api/v1/products"

      body = JSON.parse(response.body)
      expect(body["products"].size).to eq(1)
    end
  end

  describe "GET /api/v1/products/:id" do
    it "returns a single product" do
      product = create(:product, shop: shop)

      get "/api/v1/products/#{product.id}"

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["id"]).to eq(product.id)
    end
  end
end
