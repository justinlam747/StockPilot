require "rails_helper"

RSpec.describe "Security", type: :request do
  describe "authentication enforcement" do
    # Every authenticated endpoint must return 401 when no session token is provided.
    {
      "GET /api/v1/shop"              => [:get,  "/api/v1/shop"],
      "GET /api/v1/settings"          => [:get,  "/api/v1/settings"],
      "GET /api/v1/products"          => [:get,  "/api/v1/products"],
      "GET /api/v1/variants"          => [:get,  "/api/v1/variants"],
      "GET /api/v1/alerts"            => [:get,  "/api/v1/alerts"],
      "GET /api/v1/reports"           => [:get,  "/api/v1/reports"],
      "GET /api/v1/suppliers"         => [:get,  "/api/v1/suppliers"],
      "GET /api/v1/purchase_orders"   => [:get,  "/api/v1/purchase_orders"],
      "GET /api/v1/webhook_endpoints" => [:get,  "/api/v1/webhook_endpoints"],
      "GET /api/v1/ai/insights"       => [:get,  "/api/v1/ai/insights"],
      "GET /api/v1/customers"         => [:get,  "/api/v1/customers"],
      "POST /api/v1/inventory/sync"   => [:post, "/api/v1/inventory/sync"]
    }.each do |label, (verb, path)|
      it "#{label} returns 401 without authentication" do
        send(verb, path)

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "tenant isolation" do
    let(:shop_a) { create(:shop) }
    let(:shop_b) { create(:shop) }

    let!(:supplier_a) { create(:supplier, shop: shop_a, name: "Supplier A") }
    let!(:supplier_b) { create(:supplier, shop: shop_b, name: "Supplier B") }

    let(:product_a) { create(:product, shop: shop_a) }
    let(:product_b) { create(:product, shop: shop_b) }

    let(:variant_a) { create(:variant, shop: shop_a, product: product_a) }
    let(:variant_b) { create(:variant, shop: shop_b, product: product_b) }

    let!(:alert_a) { create(:alert, shop: shop_a, variant: variant_a) }
    let!(:alert_b) { create(:alert, shop: shop_b, variant: variant_b) }

    before do
      authenticate_shop(shop_a)
      ActsAsTenant.current_tenant = shop_a
    end

    it "shop_a cannot see shop_b suppliers" do
      get "/api/v1/suppliers"

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      names = body["suppliers"].map { |s| s["name"] }
      expect(names).to include("Supplier A")
      expect(names).not_to include("Supplier B")
    end

    it "shop_a cannot see shop_b alerts" do
      get "/api/v1/alerts"

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      alert_ids = body["alerts"].map { |a| a["id"] }
      expect(alert_ids).to include(alert_a.id)
      expect(alert_ids).not_to include(alert_b.id)
    end

    it "shop_a cannot see shop_b products" do
      get "/api/v1/products"

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      product_ids = body["products"].map { |p| p["id"] }
      expect(product_ids).to include(product_a.id)
      expect(product_ids).not_to include(product_b.id)
    end

    it "shop_a cannot access shop_b supplier by direct ID" do
      get "/api/v1/suppliers/#{supplier_b.id}"

      expect(response).to have_http_status(:not_found)
    end
  end
end
