require "rails_helper"

RSpec.describe Inventory::Snapshotter do
  let(:shop) { create(:shop) }
  let(:snapshotter) { described_class.new(shop) }

  it "creates snapshot rows from GraphQL product data" do
    product = create(:product, shop: shop)
    variant = create(:variant, shop: shop, product: product, shopify_variant_id: "500")

    data = {
      products: [
        {
          "variants" => {
            "nodes" => [
              {
                "legacyResourceId" => "500",
                "inventoryItem" => {
                  "inventoryLevels" => {
                    "nodes" => [
                      {
                        "quantities" => [
                          { "name" => "available", "quantity" => 10 },
                          { "name" => "on_hand", "quantity" => 15 },
                          { "name" => "committed", "quantity" => 5 },
                          { "name" => "incoming", "quantity" => 0 }
                        ]
                      },
                      {
                        "quantities" => [
                          { "name" => "available", "quantity" => 3 },
                          { "name" => "on_hand", "quantity" => 5 },
                          { "name" => "committed", "quantity" => 2 },
                          { "name" => "incoming", "quantity" => 10 }
                        ]
                      }
                    ]
                  }
                }
              }
            ]
          }
        }
      ]
    }

    ActsAsTenant.with_tenant(shop) do
      count = snapshotter.snapshot(data)
      expect(count).to eq(1)

      snapshot = InventorySnapshot.last
      expect(snapshot.available).to eq(13) # 10 + 3
      expect(snapshot.on_hand).to eq(20)   # 15 + 5
      expect(snapshot.committed).to eq(7)  # 5 + 2
      expect(snapshot.incoming).to eq(10)  # 0 + 10
    end
  end
end
