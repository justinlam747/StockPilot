# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Supplier, type: :model do
  let(:shop) { create(:shop) }

  describe 'associations' do
    subject { ActsAsTenant.with_tenant(shop) { create(:supplier, shop: shop) } }

    it { should have_many(:variants).dependent(:nullify) }
    it { should have_many(:purchase_orders).dependent(:restrict_with_error) }
  end

  describe 'validations' do
    subject { ActsAsTenant.with_tenant(shop) { create(:supplier, shop: shop) } }

    it { should validate_presence_of(:name) }
    it { should validate_length_of(:name).is_at_most(255) }

    it { should allow_value('supplier@example.com').for(:email) }
    it { should allow_value('').for(:email) }
    it { should allow_value(nil).for(:email) }
    it { should_not allow_value('not-an-email').for(:email) }
    it { should_not allow_value('missing@').for(:email) }

    it { should validate_numericality_of(:lead_time_days).only_integer.is_greater_than(0).allow_nil }
    it { should validate_numericality_of(:star_rating).only_integer.allow_nil }

    context 'star_rating range' do
      subject { ActsAsTenant.with_tenant(shop) { build(:supplier, shop: shop) } }

      it 'allows values between 0 and 5' do
        (0..5).each do |rating|
          subject.star_rating = rating
          expect(subject).to be_valid
        end
      end

      it 'rejects values outside 0 to 5' do
        subject.star_rating = -1
        expect(subject).not_to be_valid

        subject.star_rating = 6
        expect(subject).not_to be_valid
      end
    end
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
