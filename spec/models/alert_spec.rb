# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Alert do
  let(:shop) { create(:shop) }

  describe 'associations' do
    subject do
      ActsAsTenant.with_tenant(shop) do
        product = create(:product, shop: shop)
        variant = create(:variant, shop: shop, product: product)
        create(:alert, shop: shop, variant: variant)
      end
    end

    it { is_expected.to belong_to(:variant) }
  end

  describe 'validations' do
    subject do
      ActsAsTenant.with_tenant(shop) do
        product = create(:product, shop: shop)
        variant = create(:variant, shop: shop, product: product)
        create(:alert, shop: shop, variant: variant)
      end
    end

    it { is_expected.to validate_presence_of(:alert_type) }
    it { is_expected.to validate_inclusion_of(:alert_type).in_array(%w[low_stock out_of_stock]) }
    it { is_expected.to validate_presence_of(:status) }
    it { is_expected.to validate_presence_of(:channel) }
    it { is_expected.to validate_numericality_of(:threshold).only_integer.is_greater_than(0).allow_nil }

    it {
      expect(subject).to validate_numericality_of(:current_quantity)
        .only_integer.is_greater_than_or_equal_to(0).allow_nil
    }
  end

  describe 'scopes' do
    let!(:active_alert) do
      ActsAsTenant.with_tenant(shop) do
        product = create(:product, shop: shop)
        variant = create(:variant, shop: shop, product: product)
        create(:alert, shop: shop, variant: variant, dismissed: false)
      end
    end

    let!(:dismissed_alert) do
      ActsAsTenant.with_tenant(shop) do
        product = create(:product, shop: shop)
        variant = create(:variant, shop: shop, product: product)
        create(:alert, shop: shop, variant: variant, dismissed: true)
      end
    end

    describe '.active' do
      it 'returns only non-dismissed alerts' do
        ActsAsTenant.with_tenant(shop) do
          expect(described_class.active).to include(active_alert)
          expect(described_class.active).not_to include(dismissed_alert)
        end
      end
    end

    describe '.dismissed' do
      it 'returns only dismissed alerts' do
        ActsAsTenant.with_tenant(shop) do
          expect(described_class.dismissed).to include(dismissed_alert)
          expect(described_class.dismissed).not_to include(active_alert)
        end
      end
    end
  end

  describe '#severity' do
    it 'returns critical for out_of_stock alerts' do
      alert = build(:alert, alert_type: 'out_of_stock')
      expect(alert.severity).to eq('critical')
    end

    it 'returns warning for low_stock alerts' do
      alert = build(:alert, alert_type: 'low_stock')
      expect(alert.severity).to eq('warning')
    end

    it 'returns info for unknown alert types' do
      alert = build(:alert)
      alert.alert_type = 'something_else'
      expect(alert.severity).to eq('info')
    end
  end

  describe '#message' do
    let(:product) { ActsAsTenant.with_tenant(shop) { create(:product, shop: shop) } }

    it 'returns out of stock message with variant details' do
      ActsAsTenant.with_tenant(shop) do
        variant = create(:variant, shop: shop, product: product, sku: 'ABC-123', title: 'Red / Large')
        alert = create(:alert, shop: shop, variant: variant, alert_type: 'out_of_stock')

        expect(alert.message).to eq('ABC-123 — Red / Large is out of stock')
      end
    end

    it 'returns low stock message with quantity' do
      ActsAsTenant.with_tenant(shop) do
        variant = create(:variant, shop: shop, product: product, sku: 'ABC-123', title: 'Red / Large')
        alert = create(:alert, shop: shop, variant: variant, alert_type: 'low_stock', current_quantity: 3)

        expect(alert.message).to eq('ABC-123 — Red / Large is low stock (3 remaining)')
      end
    end

    it 'returns low stock message without quantity when nil' do
      ActsAsTenant.with_tenant(shop) do
        variant = create(:variant, shop: shop, product: product, sku: 'ABC-123', title: 'Red / Large')
        alert = create(:alert, shop: shop, variant: variant, alert_type: 'low_stock', current_quantity: nil)

        expect(alert.message).to eq('ABC-123 — Red / Large is low stock')
      end
    end

    it 'uses Unknown SKU when variant sku is nil' do
      ActsAsTenant.with_tenant(shop) do
        variant = create(:variant, shop: shop, product: product, sku: nil, title: 'Red / Large')
        alert = create(:alert, shop: shop, variant: variant, alert_type: 'out_of_stock')

        expect(alert.message).to eq('Unknown SKU — Red / Large is out of stock')
      end
    end
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
        expect(described_class.all).to include(alert)
        expect(described_class.all).not_to include(other_alert)
      end
    end
  end
end
