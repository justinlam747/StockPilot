# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Alert, type: :model do
  let(:shop) { create(:shop) }

  describe 'associations' do
    subject do
      ActsAsTenant.with_tenant(shop) do
        product = create(:product, shop: shop)
        variant = create(:variant, shop: shop, product: product)
        create(:alert, shop: shop, variant: variant)
      end
    end

    it { should belong_to(:variant) }
  end

  describe 'tenant scoping' do
    it 'automatically scopes to the current tenant' do
      alert = ActsAsTenant.with_tenant(shop) do
        product = create(:product, shop: shop)
        variant = create(:variant, shop: shop, product: product)
        create(:alert, shop: shop, variant: variant)
      end

      other_shop = create(:shop)
      other_alert = ActsAsTenant.with_tenant(other_shop) do
        product = create(:product, shop: other_shop)
        variant = create(:variant, shop: other_shop, product: product)
        create(:alert, shop: other_shop, variant: variant)
      end

      ActsAsTenant.with_tenant(shop) do
        expect(Alert.all).to include(alert)
        expect(Alert.all).not_to include(other_alert)
      end
    end
  end
end
