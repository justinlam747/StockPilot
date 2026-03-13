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

  describe "GET /api/v1/shop with low-stock data" do
    it "returns flagged low-stock items from the detector" do
      product = create(:product, shop: shop, title: "Widget")
      variant = create(:variant, shop: shop, product: product, sku: "WDG-001", title: "Small")

      detector = instance_double(Inventory::LowStockDetector)
      allow(Inventory::LowStockDetector).to receive(:new).and_return(detector)
      allow(detector).to receive(:detect).and_return([
        { variant: variant, status: :low_stock, available: 2, threshold: 10 },
        { variant: variant, status: :out_of_stock, available: 0, threshold: 10 }
      ])

      get "/api/v1/shop"

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["low_stock_count"]).to eq(1)
      expect(body["out_of_stock_count"]).to eq(1)
      expect(body["low_stock_items"].size).to be >= 1
      expect(body["low_stock_items"].first["sku"]).to eq("WDG-001")
    end
  end

  describe "PATCH /api/v1/shop" do
    it "updates the shop" do
      allow(Inventory::LowStockDetector).to receive(:new).and_return(
        instance_double(Inventory::LowStockDetector, detect: [])
      )

      patch "/api/v1/shop",
            params: { shop: { plan: "premium" } }.to_json,
            headers: { "Content-Type" => "application/json" }

      expect(response).to have_http_status(:ok)
      expect(shop.reload.plan).to eq("premium")
    end
  end
end
