require "rails_helper"

RSpec.describe "Api::V1::Variants", type: :request do
  let(:shop) { create(:shop) }

  before do
    authenticate_shop(shop)
    ActsAsTenant.current_tenant = shop
  end

  describe "GET /api/v1/variants" do
    it "returns an empty array" do
      get "/api/v1/variants"

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)).to eq([])
    end
  end

  describe "GET /api/v1/variants/:id" do
    it "returns an empty object" do
      product = create(:product, shop: shop)
      variant = create(:variant, shop: shop, product: product)

      get "/api/v1/variants/#{variant.id}"

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)).to eq({})
    end
  end

  describe "PATCH /api/v1/variants/:id" do
    it "returns an empty object" do
      product = create(:product, shop: shop)
      variant = create(:variant, shop: shop, product: product)

      patch "/api/v1/variants/#{variant.id}",
            params: { variant: { sku: "NEW-SKU" } }.to_json,
            headers: { "Content-Type" => "application/json" }

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)).to eq({})
    end
  end
end
