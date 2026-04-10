# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Product do
  let(:shop) { create(:shop) }

  describe 'associations' do
    subject { ActsAsTenant.with_tenant(shop) { create(:product, shop: shop) } }

    it { is_expected.to have_many(:variants).dependent(:destroy) }
  end

  describe 'validations' do
    subject { ActsAsTenant.with_tenant(shop) { create(:product, shop: shop) } }

    it { is_expected.to validate_presence_of(:shopify_product_id) }
    it { is_expected.to validate_presence_of(:title) }
    it { is_expected.to validate_length_of(:title).is_at_most(500) }
  end

  describe 'tenant scoping' do
    it 'automatically scopes to the current tenant' do
      product = ActsAsTenant.with_tenant(shop) { create(:product, shop: shop) }

      other_shop = create(:shop)
      other_product = ActsAsTenant.with_tenant(other_shop) { create(:product, shop: other_shop) }

      ActsAsTenant.with_tenant(shop) do
        expect(described_class.all).to include(product)
        expect(described_class.all).not_to include(other_product)
      end
    end
  end

  describe 'scopes' do
    describe '.active' do
      it 'returns only products without a deleted_at timestamp' do
        ActsAsTenant.with_tenant(shop) do
          active_product = create(:product, shop: shop, deleted_at: nil)
          deleted_product = create(:product, shop: shop, deleted_at: 1.day.ago)

          expect(described_class.active).to include(active_product)
          expect(described_class.active).not_to include(deleted_product)
        end
      end
    end
  end
end
