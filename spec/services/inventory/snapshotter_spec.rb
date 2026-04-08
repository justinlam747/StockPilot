# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Inventory::Snapshotter do
  let(:shop) { create(:shop) }
  let(:snapshotter) { described_class.new(shop) }

  it 'creates snapshot rows from GraphQL product data' do
    product = create(:product, shop: shop)
    create(:variant, shop: shop, product: product, shopify_variant_id: '500')

    data = {
      products: [
        {
          'variants' => {
            'nodes' => [
              {
                'legacyResourceId' => '500',
                'inventoryItem' => {
                  'inventoryLevels' => {
                    'nodes' => [
                      {
                        'quantities' => [
                          { 'name' => 'available', 'quantity' => 10 },
                          { 'name' => 'on_hand', 'quantity' => 15 },
                          { 'name' => 'committed', 'quantity' => 5 },
                          { 'name' => 'incoming', 'quantity' => 0 }
                        ]
                      },
                      {
                        'quantities' => [
                          { 'name' => 'available', 'quantity' => 3 },
                          { 'name' => 'on_hand', 'quantity' => 5 },
                          { 'name' => 'committed', 'quantity' => 2 },
                          { 'name' => 'incoming', 'quantity' => 10 }
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
      count = snapshotter.create_snapshots_from_shopify_data(data)
      expect(count).to eq(1)

      snapshot = InventorySnapshot.last
      expect(snapshot.available).to eq(13) # 10 + 3
      expect(snapshot.on_hand).to eq(20)   # 15 + 5
      expect(snapshot.committed).to eq(7)  # 5 + 2
      expect(snapshot.incoming).to eq(10)  # 0 + 10
    end
  end

  it 'returns 0 when no variants match the data' do
    data = {
      products: [
        {
          'variants' => {
            'nodes' => [
              {
                'legacyResourceId' => '99999',
                'inventoryItem' => {
                  'inventoryLevels' => {
                    'nodes' => [
                      {
                        'quantities' => [
                          { 'name' => 'available', 'quantity' => 10 },
                          { 'name' => 'on_hand', 'quantity' => 10 },
                          { 'name' => 'committed', 'quantity' => 0 },
                          { 'name' => 'incoming', 'quantity' => 0 }
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
      count = snapshotter.create_snapshots_from_shopify_data(data)
      expect(count).to eq(0)
    end
  end

  it 'creates snapshots for multiple variants across products' do
    product1 = create(:product, shop: shop)
    variant1 = create(:variant, shop: shop, product: product1, shopify_variant_id: '1001')
    product2 = create(:product, shop: shop)
    variant2 = create(:variant, shop: shop, product: product2, shopify_variant_id: '1002')

    data = {
      products: [
        {
          'variants' => {
            'nodes' => [
              {
                'legacyResourceId' => '1001',
                'inventoryItem' => {
                  'inventoryLevels' => {
                    'nodes' => [
                      {
                        'quantities' => [
                          { 'name' => 'available', 'quantity' => 5 },
                          { 'name' => 'on_hand', 'quantity' => 8 },
                          { 'name' => 'committed', 'quantity' => 3 },
                          { 'name' => 'incoming', 'quantity' => 0 }
                        ]
                      }
                    ]
                  }
                }
              }
            ]
          }
        },
        {
          'variants' => {
            'nodes' => [
              {
                'legacyResourceId' => '1002',
                'inventoryItem' => {
                  'inventoryLevels' => {
                    'nodes' => [
                      {
                        'quantities' => [
                          { 'name' => 'available', 'quantity' => 20 },
                          { 'name' => 'on_hand', 'quantity' => 25 },
                          { 'name' => 'committed', 'quantity' => 5 },
                          { 'name' => 'incoming', 'quantity' => 10 }
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
      count = snapshotter.create_snapshots_from_shopify_data(data)
      expect(count).to eq(2)

      snap1 = InventorySnapshot.find_by(variant_id: variant1.id)
      expect(snap1.available).to eq(5)

      snap2 = InventorySnapshot.find_by(variant_id: variant2.id)
      expect(snap2.available).to eq(20)
      expect(snap2.incoming).to eq(10)
    end
  end

  it 'records zeros when inventory levels are empty' do
    product = create(:product, shop: shop)
    variant = create(:variant, shop: shop, product: product, shopify_variant_id: '2000')

    data = {
      products: [
        {
          'variants' => {
            'nodes' => [
              {
                'legacyResourceId' => '2000',
                'inventoryItem' => {
                  'inventoryLevels' => {
                    'nodes' => []
                  }
                }
              }
            ]
          }
        }
      ]
    }

    ActsAsTenant.with_tenant(shop) do
      count = snapshotter.create_snapshots_from_shopify_data(data)
      expect(count).to eq(1)

      snapshot = InventorySnapshot.find_by(variant_id: variant.id)
      expect(snapshot.available).to eq(0)
      expect(snapshot.on_hand).to eq(0)
      expect(snapshot.committed).to eq(0)
      expect(snapshot.incoming).to eq(0)
    end
  end
end
