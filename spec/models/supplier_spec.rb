# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Supplier, type: :model do
  let(:shop) { create(:shop) }

  describe 'associations' do
    subject { ActsAsTenant.with_tenant(shop) { create(:supplier, shop: shop) } }

    it { should have_many(:variants).dependent(:nullify) }
    it { should have_many(:purchase_orders).dependent(:restrict_with_error) }
  end

  describe 'tenant scoping' do
    it 'automatically scopes to the current tenant' do
      supplier = ActsAsTenant.with_tenant(shop) { create(:supplier, shop: shop) }

      other_shop = create(:shop)
      other_supplier = ActsAsTenant.with_tenant(other_shop) { create(:supplier, shop: other_shop) }

      ActsAsTenant.with_tenant(shop) do
        expect(Supplier.all).to include(supplier)
        expect(Supplier.all).not_to include(other_supplier)
      end
    end
  end

  describe 'dependent nullify on variants' do
    it 'nullifies the supplier reference on variants when destroyed' do
      ActsAsTenant.with_tenant(shop) do
        supplier = create(:supplier, shop: shop)
        product = create(:product, shop: shop)
        variant = create(:variant, shop: shop, product: product, supplier: supplier)

        supplier.destroy

        expect(variant.reload.supplier_id).to be_nil
      end
    end
  end

  describe 'dependent restrict on purchase orders' do
    it 'prevents deletion when purchase orders exist' do
      ActsAsTenant.with_tenant(shop) do
        supplier = create(:supplier, shop: shop)
        create(:purchase_order, shop: shop, supplier: supplier)

        expect { supplier.destroy }.not_to change(Supplier, :count)
        expect(supplier.errors[:base]).to be_present
      end
    end
  end
end
