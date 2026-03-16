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

    it "creates multiple products with multiple variants" do
      data = {
        products: [
          {
            "legacyResourceId" => "501",
            "title" => "Product A",
            "productType" => "TypeA",
            "vendor" => "VendorA",
            "status" => "ACTIVE",
            "variants" => {
              "nodes" => [
                { "legacyResourceId" => "601", "sku" => "A-001", "title" => "Small", "price" => "10.00" },
                { "legacyResourceId" => "602", "sku" => "A-002", "title" => "Large", "price" => "15.00" }
              ]
            }
          },
          {
            "legacyResourceId" => "502",
            "title" => "Product B",
            "productType" => "TypeB",
            "vendor" => "VendorB",
            "status" => "ACTIVE",
            "variants" => {
              "nodes" => [
                { "legacyResourceId" => "603", "sku" => "B-001", "title" => "Default", "price" => "20.00" }
              ]
            }
          }
        ]
      }

      ActsAsTenant.with_tenant(shop) do
        expect { persister.upsert(data) }.to change { Product.count }.by(2)
          .and change { Variant.count }.by(3)
      end
    end

    it "handles variants with nil sku and nil title" do
      data = {
        products: [
          {
            "legacyResourceId" => "700",
            "title" => "Nil Fields Product",
            "productType" => "Widget",
            "vendor" => "TestCo",
            "status" => "ACTIVE",
            "variants" => {
              "nodes" => [
                { "legacyResourceId" => "800", "sku" => nil, "title" => nil, "price" => "5.00" }
              ]
            }
          }
        ]
      }

      ActsAsTenant.with_tenant(shop) do
        expect { persister.upsert(data) }.to change { Product.count }.by(1)
          .and change { Variant.count }.by(1)

        variant = Variant.find_by(shopify_variant_id: "800")
        expect(variant.sku).to be_nil
        expect(variant.title).to be_nil
      end
    end

    it "handles products with empty variants list" do
      data = {
        products: [
          {
            "legacyResourceId" => "900",
            "title" => "No Variants Product",
            "productType" => "Widget",
            "vendor" => "TestCo",
            "status" => "ACTIVE",
            "variants" => { "nodes" => [] }
          }
        ]
      }

      ActsAsTenant.with_tenant(shop) do
        expect { persister.upsert(data) }.to change { Product.count }.by(1)
          .and change { Variant.count }.by(0)
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

    it "updates existing product without creating duplicates" do
      ActsAsTenant.with_tenant(shop) do
        create(:product, shop: shop, shopify_product_id: "555", title: "Old Webhook Title")

        webhook_data = {
          "id" => 555,
          "title" => "Updated Webhook Title",
          "product_type" => "Gadget",
          "vendor" => "WebhookCo",
          "status" => "active",
          "variants" => [
            { "id" => 666, "sku" => "WH-002", "title" => "Medium", "price" => "14.99" }
          ]
        }

        expect { persister.upsert_single_product(webhook_data) }.not_to change { Product.count }
        expect(Product.find_by(shopify_product_id: "555").title).to eq("Updated Webhook Title")
      end
    end
  end
end
