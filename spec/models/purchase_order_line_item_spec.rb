# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PurchaseOrderLineItem, type: :model do
  let(:shop) { create(:shop) }

  describe 'associations' do
    subject do
      ActsAsTenant.with_tenant(shop) do
        supplier = create(:supplier, shop: shop)
        po = create(:purchase_order, shop: shop, supplier: supplier)
        product = create(:product, shop: shop)
        variant = create(:variant, shop: shop, product: product)
        create(:purchase_order_line_item, purchase_order: po, variant: variant)
      end
    end

    it { should belong_to(:purchase_order) }
    it { should belong_to(:variant) }
  end

  describe 'restrict_with_error on variant deletion' do
    it 'prevents variant deletion when line items reference it' do
      ActsAsTenant.with_tenant(shop) do
        supplier = create(:supplier, shop: shop)
        po = create(:purchase_order, shop: shop, supplier: supplier)
        product = create(:product, shop: shop)
        variant = create(:variant, shop: shop, product: product)
        create(:purchase_order_line_item, purchase_order: po, variant: variant)

        expect { variant.destroy }.not_to change(Variant, :count)
        expect(variant.errors[:base]).to be_present
      end
    end
  end
end
