# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PurchaseOrderLineItem do
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

    it { is_expected.to belong_to(:purchase_order) }
    it { is_expected.to belong_to(:variant) }
  end

  describe 'validations' do
    subject do
      ActsAsTenant.with_tenant(shop) do
        supplier = create(:supplier, shop: shop)
        po = create(:purchase_order, shop: shop, supplier: supplier)
        product = create(:product, shop: shop)
        variant = create(:variant, shop: shop, product: product)
        create(:purchase_order_line_item, purchase_order: po, variant: variant)
      end
    end

    it { is_expected.to validate_presence_of(:qty_ordered) }
    it { is_expected.to validate_numericality_of(:qty_ordered).only_integer.is_greater_than(0) }
    it { is_expected.to validate_numericality_of(:qty_received).only_integer.is_greater_than_or_equal_to(0) }
    it { is_expected.to validate_numericality_of(:unit_price).is_greater_than_or_equal_to(0).allow_nil }
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
