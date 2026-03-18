# frozen_string_literal: true

require 'rails_helper'

RSpec.describe InventorySnapshot, type: :model do
  let(:shop) { create(:shop) }

  describe 'associations' do
    subject do
      ActsAsTenant.with_tenant(shop) do
        product = create(:product, shop: shop)
        variant = create(:variant, shop: shop, product: product)
        create(:inventory_snapshot, shop: shop, variant: variant)
      end
    end

    it { should belong_to(:variant) }
  end

  describe 'validations' do
    subject do
      ActsAsTenant.with_tenant(shop) do
        product = create(:product, shop: shop)
        variant = create(:variant, shop: shop, product: product)
        create(:inventory_snapshot, shop: shop, variant: variant)
      end
    end

    it { should validate_presence_of(:available) }
    it { should validate_numericality_of(:available).only_integer }
    it { should validate_presence_of(:on_hand) }
    it { should validate_numericality_of(:on_hand).only_integer }
    it { should validate_presence_of(:committed) }
    it { should validate_numericality_of(:committed).only_integer.is_greater_than_or_equal_to(0) }
    it { should validate_presence_of(:incoming) }
    it { should validate_numericality_of(:incoming).only_integer.is_greater_than_or_equal_to(0) }
  end

  describe 'tenant scoping' do
    it 'automatically scopes to the current tenant' do
      snapshot = ActsAsTenant.with_tenant(shop) do
        product = create(:product, shop: shop)
        variant = create(:variant, shop: shop, product: product)
        create(:inventory_snapshot, shop: shop, variant: variant)
      end

      other_shop = create(:shop)
      other_snapshot = ActsAsTenant.with_tenant(other_shop) do
        product = create(:product, shop: other_shop)
        variant = create(:variant, shop: other_shop, product: product)
        create(:inventory_snapshot, shop: other_shop, variant: variant)
      end

      ActsAsTenant.with_tenant(shop) do
        expect(InventorySnapshot.all).to include(snapshot)
        expect(InventorySnapshot.all).not_to include(other_snapshot)
      end
    end
  end
end
