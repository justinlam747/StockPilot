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

  describe "GET /api/v1/products?filter=low_stock" do
    it "returns only low-stock products" do
      low_product = create(:product, shop: shop)
      low_variant = create(:variant, shop: shop, product: low_product)
      _normal_product = create(:product, shop: shop)

      detector = instance_double(Inventory::LowStockDetector)
      allow(Inventory::LowStockDetector).to receive(:new).and_return(detector)
      allow(detector).to receive(:detect).and_return([
        { variant: low_variant, status: :low_stock, available: 3, threshold: 10 }
      ])

      get "/api/v1/products", params: { filter: "low_stock" }

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["products"].size).to eq(1)
      expect(body["products"].first["id"]).to eq(low_product.id)
    end
  end

  describe "GET /api/v1/products?filter=out_of_stock" do
    it "returns only out-of-stock products" do
      oos_product = create(:product, shop: shop)
      oos_variant = create(:variant, shop: shop, product: oos_product)
      _stocked_product = create(:product, shop: shop)

      detector = instance_double(Inventory::LowStockDetector)
      allow(Inventory::LowStockDetector).to receive(:new).and_return(detector)
      allow(detector).to receive(:detect).and_return([
        { variant: oos_variant, status: :out_of_stock, available: 0, threshold: 10 }
      ])

      get "/api/v1/products", params: { filter: "out_of_stock" }

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["products"].size).to eq(1)
      expect(body["products"].first["id"]).to eq(oos_product.id)
    end
  end

  describe "GET /api/v1/products/:id (non-existent)" do
    it "returns 404 for a non-existent product" do
      get "/api/v1/products/999999"

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "GET /api/v1/products with pagination" do
    it "respects the per_page param" do
      create_list(:product, 5, shop: shop)

      get "/api/v1/products", params: { per_page: 2 }

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["products"].size).to eq(2)
      expect(body["meta"]["total_count"]).to eq(5)
      expect(body["meta"]["total_pages"]).to eq(3)
      expect(body["meta"]["per_page"]).to eq(2)
    end
  end
end
