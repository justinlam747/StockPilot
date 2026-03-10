require "rails_helper"

RSpec.describe Inventory::Persister do
  let(:shop) { create(:shop) }
  let(:persister) { described_class.new(shop) }

  describe "#upsert" do
    it "creates new products and variants from GraphQL data" do
      data = {
        products: [
          {
            "legacyResourceId" => "111",
            "title" => "Test Product",
            "productType" => "Widget",
            "vendor" => "TestCo",
            "status" => "ACTIVE",
            "variants" => {
              "nodes" => [
                {
                  "legacyResourceId" => "222",
                  "sku" => "SKU-001",
                  "title" => "Default",
                  "price" => "19.99"
                }
              ]
            }
          }
        ]
      }

      ActsAsTenant.with_tenant(shop) do
        expect { persister.upsert(data) }.to change { Product.count }.by(1)
          .and change { Variant.count }.by(1)

        product = Product.last
        expect(product.title).to eq("Test Product")
        expect(product.shopify_product_id).to eq("111")

        variant = Variant.last
        expect(variant.sku).to eq("SKU-001")
        expect(variant.shopify_variant_id).to eq("222")
      end
    end

    it "updates existing products without creating duplicates" do
      ActsAsTenant.with_tenant(shop) do
        create(:product, shop: shop, shopify_product_id: "111", title: "Old Title")

        data = {
          products: [
            {
              "legacyResourceId" => "111",
              "title" => "New Title",
              "productType" => "Widget",
              "vendor" => "TestCo",
              "status" => "ACTIVE",
              "variants" => { "nodes" => [] }
            }
          ]
        }

        expect { persister.upsert(data) }.not_to change { Product.count }
        expect(Product.find_by(shopify_product_id: "111").title).to eq("New Title")
      end
    end
  end

  describe "#upsert_single_product" do
    it "creates a product from webhook REST payload" do
      webhook_data = {
        "id" => 333,
        "title" => "Webhook Product",
        "product_type" => "Gadget",
        "vendor" => "WebhookCo",
        "status" => "active",
        "variants" => [
          { "id" => 444, "sku" => "WH-001", "title" => "Small", "price" => "9.99" }
        ]
      }

      ActsAsTenant.with_tenant(shop) do
        expect { persister.upsert_single_product(webhook_data) }.to change { Product.count }.by(1)
      end
    end
  end
end
