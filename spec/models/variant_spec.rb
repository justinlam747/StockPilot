# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Variant do
  let(:shop) { create(:shop) }

  describe 'associations' do
    subject do
      ActsAsTenant.with_tenant(shop) do
        create(:variant, shop: shop, product: create(:product, shop: shop))
      end
    end

    it { is_expected.to belong_to(:product) }
    it { is_expected.to belong_to(:supplier).optional }
    it { is_expected.to have_many(:inventory_snapshots).dependent(:destroy) }
    it { is_expected.to have_many(:alerts).dependent(:destroy) }
    it { is_expected.to have_many(:purchase_order_line_items).dependent(:restrict_with_error) }
  end

  describe 'validations' do
    subject do
      ActsAsTenant.with_tenant(shop) do
        create(:variant, shop: shop, product: create(:product, shop: shop))
      end
    end

    it { is_expected.to validate_presence_of(:shopify_variant_id) }
    it { is_expected.to validate_numericality_of(:price).is_greater_than_or_equal_to(0).allow_nil }
    it { is_expected.to validate_numericality_of(:low_stock_threshold).only_integer.is_greater_than(0).allow_nil }
  end

  describe 'tenant scoping' do
    it 'automatically scopes to the current tenant' do
      variant = ActsAsTenant.with_tenant(shop) do
        create(:variant, shop: shop, product: create(:product, shop: shop))
      end

      other_shop = create(:shop)
      other_variant = ActsAsTenant.with_tenant(other_shop) do
        create(:variant, shop: other_shop, product: create(:product, shop: other_shop))
      end

      ActsAsTenant.with_tenant(shop) do
        expect(described_class.all).to include(variant)
        expect(described_class.all).not_to include(other_variant)
      end
    end
  end

  describe 'supplier association' do
    it 'allows a variant without a supplier' do
      ActsAsTenant.with_tenant(shop) do
        variant = create(:variant, shop: shop, product: create(:product, shop: shop), supplier: nil)
        expect(variant).to be_valid
      end
    end

    it 'allows assigning a supplier' do
      ActsAsTenant.with_tenant(shop) do
        supplier = create(:supplier, shop: shop)
        variant = create(:variant, shop: shop, product: create(:product, shop: shop), supplier: supplier)
        expect(variant.supplier).to eq(supplier)
      end
    end
  end
end
