# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Cache::ShopCache do
  let(:shop) { create(:shop) }
  let(:cache) { described_class.new(shop) }

  before do
    ActsAsTenant.current_tenant = shop
    @original_cache = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
  end

  after do
    Rails.cache = @original_cache
  end

  describe '#suppliers' do
    it 'returns suppliers ordered by name' do
      create(:supplier, shop: shop, name: 'Zulu Supply')
      create(:supplier, shop: shop, name: 'Alpha Supply')

      result = cache.suppliers
      expect(result.map(&:name)).to eq(['Alpha Supply', 'Zulu Supply'])
    end

    it 'caches the result' do
      create(:supplier, shop: shop)

      cache.suppliers
      expect(Rails.cache.exist?("shop:#{shop.id}:suppliers:all")).to be true
    end
  end

  describe '#write_supplier' do
    it 'invalidates the supplier list cache' do
      supplier = create(:supplier, shop: shop)
      cache.suppliers # warm cache
      expect(Rails.cache.exist?("shop:#{shop.id}:suppliers:all")).to be true

      cache.write_supplier(supplier)
      expect(Rails.cache.exist?("shop:#{shop.id}:suppliers:all")).to be false
    end
  end

  describe '#invalidate_supplier' do
    it 'removes the supplier and list from cache' do
      supplier = create(:supplier, shop: shop)
      cache.suppliers # warm list
      cache.supplier(supplier.id) # warm individual

      cache.invalidate_supplier(supplier.id)
      expect(Rails.cache.exist?("shop:#{shop.id}:suppliers:#{supplier.id}")).to be false
      expect(Rails.cache.exist?("shop:#{shop.id}:suppliers:all")).to be false
    end
  end

  describe '#inventory_stats' do
    it 'returns correct stats structure' do
      stats = cache.inventory_stats
      expect(stats).to have_key(:total_products)
      expect(stats).to have_key(:low_stock)
      expect(stats).to have_key(:out_of_stock)
      expect(stats).to have_key(:pending_pos)
    end
  end

  describe '#warm_inventory_stats' do
    it 'writes stats to cache' do
      cache.warm_inventory_stats
      expect(Rails.cache.exist?("shop:#{shop.id}:inventory:stats")).to be true
    end
  end

  describe '#invalidate_all' do
    it 'clears all cache keys' do
      create(:supplier, shop: shop)
      cache.suppliers
      cache.inventory_stats

      cache.invalidate_all

      expect(Rails.cache.exist?("shop:#{shop.id}:suppliers:all")).to be false
      expect(Rails.cache.exist?("shop:#{shop.id}:inventory:stats")).to be false
    end
  end
end
