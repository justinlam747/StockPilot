# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Demo::Seeder, order: :defined do
  before(:all) do
    @original_cache = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new

    ActsAsTenant.without_tenant do
      described_class.new.seed!
      @demo_shop = Shop.find_by(shop_domain: 'demo.myshopify.com')
    end
  end

  after(:all) do
    ActsAsTenant.without_tenant do
      cleanup_demo_data!
    end
    Rails.cache = @original_cache
  end

  around do |example|
    ActsAsTenant.without_tenant { example.run }
  end

  describe '#seed!' do
    it 'creates a demo shop' do
      expect(@demo_shop).to be_present
      expect(@demo_shop.access_token).to eq('demo_token_not_real')
    end

    it 'creates a demo user' do
      user = User.find_by(clerk_user_id: 'demo_user')
      expect(user).to be_present
      expect(user.onboarding_completed?).to be true
    end

    it 'creates products with variants' do
      expect(@demo_shop.products.count).to be >= 40
      expect(@demo_shop.variants.count).to be >= 100
    end

    it 'creates suppliers from the catalog' do
      expect(@demo_shop.suppliers.count).to eq(Demo::DataCatalog.suppliers.size)
    end

    it 'creates 30 days of inventory snapshots per variant' do
      variant = @demo_shop.variants.first
      snapshots = InventorySnapshot.where(shop: @demo_shop, variant: variant)
      expect(snapshots.count).to eq(31)
    end

    it 'creates alerts for low-stock variants' do
      expect(@demo_shop.alerts.count).to be > 0
    end

    it 'creates purchase orders with line items' do
      expect(@demo_shop.purchase_orders.count).to be >= 6
      expect(PurchaseOrderLineItem.joins(:purchase_order)
        .where(purchase_orders: { shop_id: @demo_shop.id }).count).to be > 0
    end

    it 'assigns variants to their matching suppliers' do
      eco_supplier = @demo_shop.suppliers.find_by(name: 'EcoThread Co')
      eco_variants = @demo_shop.variants.joins(:product).where(products: { vendor: 'EcoThread Co' })
      expect(eco_variants.where(supplier: eco_supplier).count).to eq(eco_variants.count)
    end

    it 'is idempotent — running twice does not duplicate data' do
      first_count = @demo_shop.products.count
      described_class.new.seed!
      expect(@demo_shop.products.count).to eq(first_count)
    end
  end

  describe '#reset!' do
    it 'destroys and re-seeds the demo shop' do
      old_id = @demo_shop.id
      described_class.new.reset!
      new_shop = Shop.find_by(shop_domain: 'demo.myshopify.com')
      expect(new_shop).to be_present
      expect(new_shop.id).not_to eq(old_id)
      @demo_shop = new_shop
    end
  end

  describe 'tenant isolation' do
    it 'demo data does not appear under other shops' do
      real_shop = create(:shop)
      ActsAsTenant.with_tenant(real_shop) do
        expect(Product.count).to eq(0)
        expect(Variant.count).to eq(0)
        expect(Supplier.count).to eq(0)
      end
    end
  end

  private

  def cleanup_demo_data!
    shop = Shop.find_by(shop_domain: 'demo.myshopify.com')
    return unless shop

    # Nullify user FK before deleting the shop
    User.where(active_shop_id: shop.id).update_all(active_shop_id: nil)
    # Use delete_all with SQL to avoid AR callback dependency issues
    PurchaseOrderLineItem.where(
      purchase_order_id: PurchaseOrder.where(shop_id: shop.id).select(:id)
    ).delete_all
    PurchaseOrder.where(shop_id: shop.id).delete_all
    Alert.where(shop_id: shop.id).delete_all
    InventorySnapshot.where(shop_id: shop.id).delete_all
    Variant.where(shop_id: shop.id).delete_all
    Product.where(shop_id: shop.id).delete_all
    Supplier.where(shop_id: shop.id).delete_all
    AuditLog.where(shop_id: shop.id).delete_all
    shop.delete
    User.find_by(clerk_user_id: 'demo_user')&.delete
  end
end
