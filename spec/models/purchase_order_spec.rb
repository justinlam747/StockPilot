# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PurchaseOrder, type: :model do
  let(:shop) { create(:shop) }

  describe 'associations' do
    subject do
      ActsAsTenant.with_tenant(shop) do
        supplier = create(:supplier, shop: shop)
        create(:purchase_order, shop: shop, supplier: supplier)
      end
    end

    it { should belong_to(:supplier) }
    it { should have_many(:line_items).class_name('PurchaseOrderLineItem').dependent(:destroy) }
  end

  describe 'nested attributes' do
    it 'accepts nested attributes for line items' do
      ActsAsTenant.with_tenant(shop) do
        supplier = create(:supplier, shop: shop)
        product = create(:product, shop: shop)
        variant = create(:variant, shop: shop, product: product)

        po = PurchaseOrder.create!(
          shop: shop,
          supplier: supplier,
          status: 'draft',
          order_date: Date.current,
          expected_delivery: Date.current + 14.days,
          line_items_attributes: [
            { variant: variant, sku: 'SKU-001', qty_ordered: 10, unit_price: 5.00 }
          ]
        )

        expect(po.line_items.count).to eq(1)
        expect(po.line_items.first.sku).to eq('SKU-001')
      end
    end
  end

  describe 'tenant scoping' do
    it 'automatically scopes to the current tenant' do
      po = ActsAsTenant.with_tenant(shop) do
        supplier = create(:supplier, shop: shop)
        create(:purchase_order, shop: shop, supplier: supplier)
      end

      other_shop = create(:shop)
      other_po = ActsAsTenant.with_tenant(other_shop) do
        supplier = create(:supplier, shop: other_shop)
        create(:purchase_order, shop: other_shop, supplier: supplier)
      end

      ActsAsTenant.with_tenant(shop) do
        expect(PurchaseOrder.all).to include(po)
        expect(PurchaseOrder.all).not_to include(other_po)
      end
    end
  end
end
