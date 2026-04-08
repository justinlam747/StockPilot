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

  # ---------------------------------------------------------------------------
  # Class method: .latest_per_variant
  # Uses PostgreSQL DISTINCT ON to grab the most recent snapshot per variant.
  # ---------------------------------------------------------------------------
  describe '.latest_per_variant' do
    let(:product) { create(:product, shop: shop) }
    let(:variant_a) { create(:variant, shop: shop, product: product) }
    let(:variant_b) { create(:variant, shop: shop, product: product) }

    before do
      ActsAsTenant.with_tenant(shop) do
        # Variant A: two snapshots — older (available=10) and newer (available=30)
        create(:inventory_snapshot, shop: shop, variant: variant_a, available: 10, created_at: 2.days.ago)
        create(:inventory_snapshot, shop: shop, variant: variant_a, available: 30, created_at: 1.day.ago)

        # Variant B: one snapshot (available=20)
        create(:inventory_snapshot, shop: shop, variant: variant_b, available: 20, created_at: 1.day.ago)
      end
    end

    it 'returns the most recent snapshot for each variant' do
      ActsAsTenant.with_tenant(shop) do
        results = InventorySnapshot.latest_per_variant(shop_id: shop.id)
        lookup = results.index_by(&:variant_id)

        expect(lookup.keys).to contain_exactly(variant_a.id, variant_b.id)
        expect(lookup[variant_a.id].available).to eq(30) # newer snapshot wins
        expect(lookup[variant_b.id].available).to eq(20)
      end
    end

    it 'filters by variant_ids when provided' do
      ActsAsTenant.with_tenant(shop) do
        results = InventorySnapshot.latest_per_variant(shop_id: shop.id, variant_ids: [variant_a.id])

        expect(results.map(&:variant_id)).to eq([variant_a.id])
      end
    end

    it 'selects only requested columns' do
      ActsAsTenant.with_tenant(shop) do
        results = InventorySnapshot.latest_per_variant(
          shop_id: shop.id,
          columns: %w[variant_id available on_hand]
        )
        row = results.first

        # Requested columns should be present
        expect(row.variant_id).to be_present
        expect(row.available).to be_present
        expect(row.on_hand).to be_present
      end
    end

    it 'raises ArgumentError for invalid columns' do
      ActsAsTenant.with_tenant(shop) do
        expect {
          InventorySnapshot.latest_per_variant(shop_id: shop.id, columns: %w[variant_id hacked])
        }.to raise_error(ArgumentError, /Invalid columns: hacked/)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Class method: .daily_totals
  # Aggregates available stock by day for chart rendering.
  # ---------------------------------------------------------------------------
  describe '.daily_totals' do
    let(:product) { create(:product, shop: shop) }
    let(:variant_a) { create(:variant, shop: shop, product: product) }
    let(:variant_b) { create(:variant, shop: shop, product: product) }

    it 'returns a hash of date => total available for the last N days' do
      # Freeze time so dates are deterministic and we avoid midnight flakiness
      travel_to Time.zone.parse('2026-04-08 12:00:00') do
        ActsAsTenant.with_tenant(shop) do
          # Day -2: variant_a=10, variant_b=5 → total 15
          create(:inventory_snapshot, shop: shop, variant: variant_a, available: 10, created_at: 2.days.ago)
          create(:inventory_snapshot, shop: shop, variant: variant_b, available: 5,  created_at: 2.days.ago)

          # Day -1: variant_a=20 → total 20
          create(:inventory_snapshot, shop: shop, variant: variant_a, available: 20, created_at: 1.day.ago)

          result = InventorySnapshot.daily_totals(variant_ids: [variant_a.id, variant_b.id], days: 3)

          # Expect 3 entries (today, yesterday, day before), zero-filled for missing days
          expect(result.keys.length).to eq(3)
          expect(result[Date.parse('2026-04-06')]).to eq(15)  # day -2
          expect(result[Date.parse('2026-04-07')]).to eq(20)  # day -1
          expect(result[Date.parse('2026-04-08')]).to eq(0)   # today — no snapshots
        end
      end
    end
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
