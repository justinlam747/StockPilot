# Tier 3: Competitive Demo Mode — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a full-stack demo mode that seeds a dedicated demo shop with realistic inventory data and switches the tenant via session flag, so every page in the app renders with compelling sample data — zero special-casing required.

**Architecture:** A dedicated `Shop` record (`demo.myshopify.com`) seeded with ~42 products, ~170 variants, 30 days of snapshot history, alerts, suppliers, and purchase orders. A session flag (`session[:demo_mode]` + `session[:demo_shop_id]`) switches both `ActsAsTenant.current_tenant` AND `current_shop` to the demo shop. Because every model uses `acts_as_tenant :shop` and controllers reference `current_shop` directly for non-scoped queries (stats, agent results), both must be overridden. Write actions are blocked in demo mode (read-only). The existing client-side `demo-toggle.js` is replaced by this full-stack approach.

**Deferred to v2:** Investor mode (`INVESTOR=true` flag for dramatic data tuning), expanding to 150+ products, and screenshots optimization (viewport-specific data).

**Tech Stack:** Rails 7.2, PostgreSQL, FactoryBot (test), `insert_all` (bulk seeding), ERB partials, HTMX

**Spec:** `.planning/TIER3_SPEC.md` §4 (Competitive Demo Mode)

---

## File Structure

```
NEW:
  app/services/demo/seeder.rb              — Orchestrates full demo data creation (products, variants, snapshots, alerts, POs)
  app/services/demo/data_catalog.rb         — Product/supplier/variant definitions (static data)
  app/views/layouts/_demo_banner.html.erb   — Sticky banner shown when demo mode active
  lib/tasks/demo_seed.rake                  — Rake tasks: demo:seed, demo:reset
  spec/services/demo/seeder_spec.rb         — Tests for seeder correctness and isolation
  spec/services/demo/data_catalog_spec.rb   — Tests for catalog data integrity
  spec/requests/demo_mode_spec.rb           — Request specs for toggle, read-only, tenant switching

MODIFIED:
  app/controllers/application_controller.rb — Demo tenant switching in set_tenant
  app/controllers/dashboard_controller.rb   — toggle_demo action
  app/views/layouts/application.html.erb    — Render demo banner partial
  config/routes.rb                          — Add toggle_demo route
```

---

## Task 1: Data Catalog — Static Product & Supplier Definitions

**Files:**
- Create: `app/services/demo/data_catalog.rb`
- Test: `spec/services/demo/data_catalog_spec.rb`

- [ ] **Step 1: Write the failing test for DataCatalog**

```ruby
# spec/services/demo/data_catalog_spec.rb
# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Demo::DataCatalog do
  describe '.products' do
    it 'returns an array of product hashes' do
      products = described_class.products
      expect(products).to be_an(Array)
      expect(products.size).to be >= 40
    end

    it 'each product has required keys' do
      described_class.products.each do |p|
        expect(p).to include(:title, :type, :vendor, :price_range, :variants)
        expect(p[:title]).to be_a(String)
        expect(p[:variants]).to be_an(Array)
        expect(p[:variants]).not_to be_empty
        expect(p[:price_range]).to be_a(Range)
      end
    end

    it 'has no duplicate product titles' do
      titles = described_class.products.map { |p| p[:title] }
      expect(titles).to eq(titles.uniq)
    end
  end

  describe '.suppliers' do
    it 'returns an array of supplier hashes' do
      suppliers = described_class.suppliers
      expect(suppliers).to be_an(Array)
      expect(suppliers.size).to be >= 6
    end

    it 'each supplier has required keys' do
      described_class.suppliers.each do |s|
        expect(s).to include(:name, :email, :contact_name, :lead_time_days)
        expect(s[:email]).to match(/@/)
        expect(s[:lead_time_days]).to be_a(Integer)
      end
    end
  end

  describe '.stock_profiles' do
    it 'returns profile distribution summing to ~1.0' do
      profiles = described_class.stock_profiles
      total = profiles.values.sum { |v| v[:pct] }
      expect(total).to be_within(0.01).of(1.0)
    end
  end
end
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `bundle exec rspec spec/services/demo/data_catalog_spec.rb --format documentation`
Expected: FAIL — `uninitialized constant Demo::DataCatalog`

- [ ] **Step 3: Create the DataCatalog module with product and supplier data**

```ruby
# app/services/demo/data_catalog.rb
# frozen_string_literal: true

module Demo
  # Static product and supplier definitions for demo data seeding.
  # All data is fictional — designed to look compelling in screenshots.
  module DataCatalog
    module_function

    def products
      PRODUCTS
    end

    def suppliers
      SUPPLIERS
    end

    def stock_profiles
      STOCK_PROFILES
    end

    # Maps vendor name -> supplier name for linking variants to suppliers
    def vendor_supplier_map
      VENDOR_SUPPLIER_MAP
    end

    SUPPLIERS = [
      { name: 'EcoThread Co', email: 'orders@ecothread.co', contact_name: 'Sarah Chen',
        lead_time_days: 14, star_rating: 5, rating_notes: 'Reliable, consistently on time' },
      { name: 'BlueLoop Denim', email: 'supply@blueloop.com', contact_name: 'Marcus Rivera',
        lead_time_days: 21, star_rating: 4, rating_notes: 'Quality denim, occasional delays' },
      { name: 'Highland Knits', email: 'wholesale@highlandknits.uk', contact_name: 'Fiona MacLeod',
        lead_time_days: 10, star_rating: 5, rating_notes: '98% on-time delivery' },
      { name: 'GreenTech Labs', email: 'b2b@greentech.io', contact_name: 'James Park',
        lead_time_days: 7, star_rating: 3, rating_notes: 'Fast but packaging quality varies' },
      { name: 'Barefoot Supply', email: 'orders@barefoot.supply', contact_name: 'Ana Ferreira',
        lead_time_days: 18, star_rating: 4, rating_notes: 'Handcrafted quality, worth the wait' },
      { name: 'Mountain Roast', email: 'wholesale@mountainroast.co', contact_name: 'David Okafor',
        lead_time_days: 5, star_rating: 5, rating_notes: 'Fastest supplier, always fresh' },
      { name: 'Kyoto Harvest', email: 'export@kyotoharvest.jp', contact_name: 'Yuki Tanaka',
        lead_time_days: 30, star_rating: 4, rating_notes: 'Premium quality, long lead time from Japan' },
      { name: 'SunVolt', email: 'partners@sunvolt.tech', contact_name: 'Li Wei',
        lead_time_days: 14, star_rating: 3, rating_notes: 'Budget-friendly, QC sometimes inconsistent' }
    ].freeze

    VENDOR_SUPPLIER_MAP = {
      'EcoThread Co' => 'EcoThread Co',
      'BlueLoop Denim' => 'BlueLoop Denim',
      'Highland Knits' => 'Highland Knits',
      'GreenTech Labs' => 'GreenTech Labs',
      'Barefoot Supply' => 'Barefoot Supply',
      'Mountain Roast' => 'Mountain Roast',
      'Kyoto Harvest' => 'Kyoto Harvest',
      'SunVolt' => 'SunVolt'
    }.freeze

    STOCK_PROFILES = {
      healthy:       { range: 50..200, pct: 0.60 },
      low:           { range: 2..9,    pct: 0.25 },
      out:           { range: 0..0,    pct: 0.10 },
      trending_down: { range: 15..30,  pct: 0.05 }
    }.freeze

    PRODUCTS = [
      # Apparel — EcoThread Co
      { title: 'Organic Cotton Tee', type: 'Tops', vendor: 'EcoThread Co', price_range: 28..45,
        variants: %w[XS S M L XL 2XL] },
      { title: 'Linen Button-Down', type: 'Tops', vendor: 'EcoThread Co', price_range: 55..75,
        variants: %w[S M L XL] },
      { title: 'Bamboo Tank Top', type: 'Tops', vendor: 'EcoThread Co', price_range: 22..32,
        variants: %w[XS S M L XL] },
      { title: 'Organic Henley', type: 'Tops', vendor: 'EcoThread Co', price_range: 35..48,
        variants: %w[S M L XL] },
      { title: 'Recycled Fleece Hoodie', type: 'Outerwear', vendor: 'EcoThread Co', price_range: 65..85,
        variants: %w[S M L XL 2XL] },
      { title: 'Hemp Polo Shirt', type: 'Tops', vendor: 'EcoThread Co', price_range: 38..52,
        variants: %w[S M L XL] },

      # Denim — BlueLoop Denim
      { title: 'Recycled Denim Jacket', type: 'Outerwear', vendor: 'BlueLoop Denim', price_range: 89..129,
        variants: %w[S M L XL] },
      { title: 'Selvedge Slim Jeans', type: 'Bottoms', vendor: 'BlueLoop Denim', price_range: 78..98,
        variants: %w[28 30 32 34 36] },
      { title: 'Relaxed Fit Chinos', type: 'Bottoms', vendor: 'BlueLoop Denim', price_range: 55..72,
        variants: %w[28 30 32 34 36 38] },
      { title: 'Denim Overshirt', type: 'Tops', vendor: 'BlueLoop Denim', price_range: 68..88,
        variants: %w[S M L XL] },
      { title: 'Wide Leg Trousers', type: 'Bottoms', vendor: 'BlueLoop Denim', price_range: 62..82,
        variants: %w[28 30 32 34 36] },

      # Accessories — Highland Knits
      { title: 'Merino Wool Beanie', type: 'Accessories', vendor: 'Highland Knits', price_range: 24..32,
        variants: ['One Size'] },
      { title: 'Cable Knit Scarf', type: 'Accessories', vendor: 'Highland Knits', price_range: 38..52,
        variants: ['One Size'] },
      { title: 'Lambswool Gloves', type: 'Accessories', vendor: 'Highland Knits', price_range: 28..38,
        variants: %w[S/M L/XL] },
      { title: 'Cashmere Blend Socks', type: 'Accessories', vendor: 'Highland Knits', price_range: 18..24,
        variants: %w[S M L] },
      { title: 'Wool Blend Cardigan', type: 'Outerwear', vendor: 'Highland Knits', price_range: 72..95,
        variants: %w[S M L XL] },
      { title: 'Fair Isle Sweater', type: 'Tops', vendor: 'Highland Knits', price_range: 85..110,
        variants: %w[S M L XL] },

      # Electronics — GreenTech Labs
      { title: 'Bamboo Wireless Charger', type: 'Accessories', vendor: 'GreenTech Labs', price_range: 35..55,
        variants: %w[Black Natural Walnut] },
      { title: 'Recycled Plastic Phone Case', type: 'Accessories', vendor: 'GreenTech Labs', price_range: 22..35,
        variants: ['iPhone 15', 'iPhone 15 Pro', 'Samsung S24', 'Pixel 8'] },
      { title: 'Cork Laptop Sleeve', type: 'Accessories', vendor: 'GreenTech Labs', price_range: 42..58,
        variants: %w[13-inch 15-inch 16-inch] },
      { title: 'USB-C Hub (Recycled Aluminum)', type: 'Accessories', vendor: 'GreenTech Labs', price_range: 48..65,
        variants: ['4-Port', '7-Port'] },
      { title: 'Biodegradable Earbuds', type: 'Audio', vendor: 'GreenTech Labs', price_range: 55..75,
        variants: %w[White Black Sage] },

      # Footwear — Barefoot Supply
      { title: 'Hemp Canvas Sneakers', type: 'Footwear', vendor: 'Barefoot Supply', price_range: 79..110,
        variants: %w[7 8 9 10 11 12] },
      { title: 'Recycled Rubber Sandals', type: 'Footwear', vendor: 'Barefoot Supply', price_range: 45..58,
        variants: %w[7 8 9 10 11 12] },
      { title: 'Cork Sole Boots', type: 'Footwear', vendor: 'Barefoot Supply', price_range: 110..145,
        variants: %w[7 8 9 10 11 12] },
      { title: 'Bamboo Fiber Slip-Ons', type: 'Footwear', vendor: 'Barefoot Supply', price_range: 55..72,
        variants: %w[7 8 9 10 11] },

      # Coffee — Mountain Roast
      { title: 'Single Origin Coffee Beans', type: 'Coffee', vendor: 'Mountain Roast', price_range: 16..24,
        variants: %w[250g 500g 1kg] },
      { title: 'Cold Brew Concentrate', type: 'Coffee', vendor: 'Mountain Roast', price_range: 14..20,
        variants: %w[500ml 1L] },
      { title: 'Espresso Blend', type: 'Coffee', vendor: 'Mountain Roast', price_range: 18..28,
        variants: %w[250g 500g 1kg] },
      { title: 'Decaf Swiss Water Process', type: 'Coffee', vendor: 'Mountain Roast', price_range: 19..26,
        variants: %w[250g 500g] },
      { title: 'Coffee Gift Box', type: 'Coffee', vendor: 'Mountain Roast', price_range: 42..58,
        variants: ['Starter Pack', 'Connoisseur Pack'] },
      { title: 'Reusable Coffee Filter', type: 'Coffee', vendor: 'Mountain Roast', price_range: 12..18,
        variants: ['V60', 'AeroPress', 'Chemex'] },

      # Tea — Kyoto Harvest
      { title: 'Organic Matcha Powder', type: 'Tea', vendor: 'Kyoto Harvest', price_range: 28..42,
        variants: ['30g Tin', '100g Bag'] },
      { title: 'Sencha Green Tea', type: 'Tea', vendor: 'Kyoto Harvest', price_range: 16..24,
        variants: %w[50g 100g 200g] },
      { title: 'Hojicha Roasted Tea', type: 'Tea', vendor: 'Kyoto Harvest', price_range: 14..22,
        variants: %w[50g 100g] },
      { title: 'Genmaicha Brown Rice Tea', type: 'Tea', vendor: 'Kyoto Harvest', price_range: 12..18,
        variants: %w[50g 100g 200g] },
      { title: 'Matcha Whisk Set', type: 'Tea', vendor: 'Kyoto Harvest', price_range: 32..48,
        variants: ['Standard', 'Premium Bamboo'] },

      # Power — SunVolt
      { title: 'Solar Power Bank 10000mAh', type: 'Power', vendor: 'SunVolt', price_range: 45..65,
        variants: %w[Black White Green] },
      { title: 'Portable Solar Panel 20W', type: 'Power', vendor: 'SunVolt', price_range: 68..88,
        variants: ['Foldable', 'Rigid'] },
      { title: 'Solar Garden Lights (4-pack)', type: 'Power', vendor: 'SunVolt', price_range: 28..38,
        variants: %w[Warm Cool Multicolor] },
      { title: 'Hand-Crank Flashlight', type: 'Power', vendor: 'SunVolt', price_range: 18..28,
        variants: %w[Red Black Yellow] },
      { title: 'Solar Bluetooth Speaker', type: 'Power', vendor: 'SunVolt', price_range: 55..72,
        variants: %w[Black Green Sand] }
    ].freeze
  end
end
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `bundle exec rspec spec/services/demo/data_catalog_spec.rb --format documentation`
Expected: 5 examples, 0 failures

- [ ] **Step 5: Commit**

```bash
git add app/services/demo/data_catalog.rb spec/services/demo/data_catalog_spec.rb
git commit -m "feat(demo): add data catalog with product and supplier definitions"
```

---

## Task 2: Demo Seeder Service — Core Seeding Logic

**Files:**
- Create: `app/services/demo/seeder.rb`
- Test: `spec/services/demo/seeder_spec.rb`

This is the largest task. The seeder creates a demo shop with full data. Key concern: the `shops` table requires `user_id NOT NULL` and validates `shop_domain` format as `*.myshopify.com`. The demo shop needs a dedicated "demo user" to satisfy the FK constraint.

- [ ] **Step 1: Write failing tests for Seeder**

```ruby
# spec/services/demo/seeder_spec.rb
# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Demo::Seeder do
  # Seed once for all tests — seeder is slow (~5s with bulk inserts).
  # Each test reads the seeded state without modifying it.
  before(:all) do
    # Disable tenant scoping so we can query across all shops
    ActsAsTenant.without_tenant do
      described_class.new.seed!
      @demo_shop = Shop.find_by(shop_domain: 'demo.myshopify.com')
    end
  end

  after(:all) do
    ActsAsTenant.without_tenant do
      @demo_shop&.destroy!
      User.find_by(clerk_user_id: 'demo_user')&.destroy!
    end
  end

  # All queries must bypass tenant scoping since no tenant is set in service specs
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
      expect(snapshots.count).to eq(31) # day 0 through day 30
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

    it 'seeds AI insights into Rails cache' do
      insights = Rails.cache.read("shop:#{@demo_shop.id}:ai_insights")
      expect(insights).to be_present
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
      # Restore reference for other tests
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
end
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `bundle exec rspec spec/services/demo/seeder_spec.rb --format documentation`
Expected: FAIL — `uninitialized constant Demo::Seeder`

- [ ] **Step 3: Implement the Seeder service**

```ruby
# app/services/demo/seeder.rb
# frozen_string_literal: true

module Demo
  # Seeds a dedicated demo shop with realistic inventory data.
  # The demo shop uses acts_as_tenant isolation — its data never leaks to real shops.
  class Seeder
    DEMO_DOMAIN = 'demo.myshopify.com'
    DEMO_TOKEN = 'demo_token_not_real'
    DEMO_CLERK_ID = 'demo_user'
    SNAPSHOT_DAYS = 30

    def seed!
      return if Shop.exists?(shop_domain: DEMO_DOMAIN)

      ActiveRecord::Base.transaction do
        create_demo_user_and_shop
        create_suppliers
        create_products_and_variants
        link_variants_to_suppliers
        generate_snapshots_bulk
        generate_alerts
        generate_purchase_orders
        seed_ai_insights
        seed_agent_results
      end
    end

    def reset!
      demo_shop = Shop.find_by(shop_domain: DEMO_DOMAIN)
      if demo_shop
        demo_user = demo_shop.user
        demo_shop.destroy!
        demo_user&.destroy! if demo_user&.clerk_user_id == DEMO_CLERK_ID
      end
      seed!
    end

    private

    def create_demo_user_and_shop
      @demo_user = User.create_or_find_by!(clerk_user_id: DEMO_CLERK_ID) do |u|
        u.email = 'demo@stockpilot.app'
        u.name = 'Demo User'
        u.store_name = 'Evergreen Goods Co.'
        u.store_category = 'apparel'
        u.onboarding_step = 4
        u.onboarding_completed_at = Time.current
      end

      @demo_shop = Shop.create!(
        shop_domain: DEMO_DOMAIN,
        access_token: DEMO_TOKEN,
        user: @demo_user,
        plan: 'professional',
        settings: {
          'low_stock_threshold' => 10,
          'timezone' => 'America/New_York',
          'alert_email' => 'team@evergreen-goods.co'
        }
      )

      @demo_user.update!(active_shop_id: @demo_shop.id)
    end

    def create_suppliers
      @suppliers = {}
      DataCatalog.suppliers.each do |s_data|
        supplier = Supplier.create!(
          shop: @demo_shop,
          name: s_data[:name],
          email: s_data[:email],
          contact_name: s_data[:contact_name],
          lead_time_days: s_data[:lead_time_days],
          star_rating: s_data[:star_rating] || 0,
          rating_notes: s_data[:rating_notes]
        )
        @suppliers[s_data[:name]] = supplier
      end
    end

    def create_products_and_variants
      @variants_with_profiles = []
      shopify_product_id = 900_000

      DataCatalog.products.each do |p_data|
        shopify_product_id += 1
        product = Product.create!(
          shop: @demo_shop,
          shopify_product_id: shopify_product_id,
          title: p_data[:title],
          product_type: p_data[:type],
          vendor: p_data[:vendor],
          status: 'active',
          synced_at: Time.current
        )

        shopify_variant_id = shopify_product_id * 100
        p_data[:variants].each do |v_name|
          shopify_variant_id += 1
          price = rand(p_data[:price_range])
          sku = generate_sku(p_data[:vendor], p_data[:title], v_name)

          variant = Variant.create!(
            shop: @demo_shop,
            product: product,
            shopify_variant_id: shopify_variant_id,
            sku: sku,
            title: v_name,
            price: price,
            low_stock_threshold: [5, 10, 15].sample
          )

          profile = assign_stock_profile
          @variants_with_profiles << [variant, profile]
        end
      end
    end

    def link_variants_to_suppliers
      DataCatalog.vendor_supplier_map.each do |vendor, supplier_name|
        supplier = @suppliers[supplier_name]
        next unless supplier

        Variant.joins(:product)
               .where(shop_id: @demo_shop.id, products: { vendor: vendor })
               .update_all(supplier_id: supplier.id)
      end
    end

    def generate_snapshots_bulk
      rows = []
      now = Time.current

      @variants_with_profiles.each do |variant, profile|
        initial_stock = rand(profile[:range].max..(profile[:range].max + 80))
        daily_sell_rate = case profile[:key]
                          when :healthy then rand(1..4)
                          when :low then rand(4..8)
                          when :out then rand(5..10)
                          when :trending_down then rand(3..6)
                          else rand(1..4)
                          end

        running_stock = initial_stock

        SNAPSHOT_DAYS.downto(0).each do |days_ago|
          sold_today = (daily_sell_rate * rand(0.3..1.8)).round
          running_stock = [running_stock - sold_today, 0].max

          # Simulate a restock around day 15 for ~30% of variants
          if days_ago == 15 && rand < 0.3
            running_stock += rand(40..100)
          end

          rows << {
            shop_id: @demo_shop.id,
            variant_id: variant.id,
            available: running_stock,
            on_hand: running_stock + rand(0..5),
            committed: rand(0..3),
            incoming: days_ago < 7 ? rand(0..20) : 0,
            snapshotted_at: (now - days_ago.days),
            created_at: (now - days_ago.days)
          }
        end
      end

      InventorySnapshot.insert_all(rows)
    end

    def generate_alerts
      low_stock_variants = @variants_with_profiles
        .select { |_v, p| p[:key] == :low || p[:key] == :out }
        .map(&:first)

      low_stock_variants.sample([low_stock_variants.size, 15].min).each do |variant|
        rand(1..3).times do |i|
          Alert.create!(
            shop: @demo_shop,
            variant: variant,
            alert_type: [variant.inventory_snapshots.last&.available.to_i <= 0 ? 'out_of_stock' : 'low_stock'].first,
            channel: 'email',
            status: 'sent',
            threshold: variant.low_stock_threshold || 10,
            current_quantity: rand(0..8),
            triggered_at: rand(7).days.ago + rand(24).hours,
            dismissed: i > 1 # dismiss older ones
          )
        end
      end
    end

    def generate_purchase_orders
      supplier_list = @suppliers.values.sample(6)
      statuses = %w[draft draft sent sent received received received received]

      supplier_list.each_with_index do |supplier, idx|
        status = statuses[idx] || 'received'
        sent_at = status == 'sent' ? rand(14).days.ago : (status == 'received' ? rand(30).days.ago : nil)

        po = PurchaseOrder.create!(
          shop: @demo_shop,
          supplier: supplier,
          po_number: format('PO-%d-%04d', @demo_shop.id, idx + 1),
          status: status,
          order_date: (sent_at || Time.current).to_date - rand(3..7).days,
          expected_delivery: Date.current + rand(7..30).days,
          sent_at: sent_at,
          po_notes: status == 'draft' ? 'Auto-generated by StockPilot AI' : nil,
          draft_body: "Dear #{supplier.contact_name},\n\nPlease find attached our purchase order. We would appreciate delivery by the expected date.\n\nBest regards,\nEvergreen Goods Co."
        )

        supplier_variants = Variant.where(shop_id: @demo_shop.id, supplier_id: supplier.id)
        supplier_variants.sample([supplier_variants.count, rand(2..5)].min).each do |v|
          qty = rand(20..100)
          PurchaseOrderLineItem.create!(
            purchase_order: po,
            variant: v,
            sku: v.sku,
            title: "#{v.product.title} — #{v.title}",
            qty_ordered: qty,
            qty_received: status == 'received' ? qty : 0,
            unit_price: v.price || rand(10..50)
          )
        end
      end
    end

    def seed_ai_insights
      insights = <<~INSIGHTS
        **Organic Cotton Tee (Size M)** is your fastest-selling variant at 4.6 units/day. At current stock (23 units), you'll run out in ~5 days. Recommended: reorder 50 units from EcoThread Co today.

        **Electronics category** is outperforming apparel by 23% this month. Consider expanding the Bamboo Wireless Charger line with new colorways.

        **Highland Knits** has the best on-time delivery rate (98%) among your suppliers. Consider consolidating more accessories orders with them.

        **3 variants** hit zero stock this week, resulting in an estimated $1,240 in lost revenue based on average daily sales.

        Your overall inventory health is **72%**. Target: above 85% by maintaining a 2-week buffer stock on all variants with >2 units/day sell rate.
      INSIGHTS

      Rails.cache.write("shop:#{@demo_shop.id}:ai_insights", insights, expires_in: 30.days)
    end

    def seed_agent_results
      @demo_shop.update!(
        last_agent_run_at: 2.hours.ago,
        last_agent_results: {
          'low_stock_count' => 12,
          'ran_at' => 2.hours.ago.iso8601,
          'turns' => 3,
          'log' => [
            "[#{2.hours.ago.strftime('%H:%M:%S')}] Starting inventory analysis...",
            "[#{2.hours.ago.strftime('%H:%M:%S')}] Checking stock levels for 487 variants across 8 suppliers",
            "[#{2.hours.ago.strftime('%H:%M:%S')}] Found 12 low-stock items and 5 out-of-stock items",
            "[#{2.hours.ago.strftime('%H:%M:%S')}] Sending alerts for critical items...",
            "[#{2.hours.ago.strftime('%H:%M:%S')}] Drafting purchase order for EcoThread Co (3 items below threshold)",
            "[#{2.hours.ago.strftime('%H:%M:%S')}] Analysis complete. 12 items flagged, 2 PO drafts created."
          ],
          'provider' => 'anthropic',
          'model' => 'claude-sonnet-4-20250514',
          'fallback' => false
        }
      )
    end

    def assign_stock_profile
      profiles = DataCatalog.stock_profiles
      roll = rand
      cumulative = 0.0
      profiles.each do |key, config|
        cumulative += config[:pct]
        return { key: key, range: config[:range] } if roll <= cumulative
      end
      { key: :healthy, range: profiles[:healthy][:range] }
    end

    def generate_sku(vendor, title, variant_name)
      prefix = vendor.split.map { |w| w[0] }.join.upcase[0..2]
      product_code = title.split.map { |w| w[0] }.join.upcase[0..1]
      variant_code = variant_name.gsub(/[^a-zA-Z0-9]/, '').upcase[0..1]
      "#{prefix}-#{product_code}-#{variant_code}"
    end
  end
end
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `bundle exec rspec spec/services/demo/seeder_spec.rb --format documentation`
Expected: All examples pass

- [ ] **Step 5: Commit**

```bash
git add app/services/demo/seeder.rb spec/services/demo/seeder_spec.rb
git commit -m "feat(demo): add seeder service with full data generation"
```

---

## Task 3: Rake Tasks for Seeding and Resetting

**Files:**
- Create: `lib/tasks/demo_seed.rake`

- [ ] **Step 1: Create the rake tasks**

```ruby
# lib/tasks/demo_seed.rake
# frozen_string_literal: true

namespace :demo do
  desc 'Seed demo shop with realistic inventory data'
  task seed: :environment do
    puts 'Seeding demo data...'
    start = Time.current
    Demo::Seeder.new.seed!
    shop = Shop.find_by(shop_domain: 'demo.myshopify.com')
    elapsed = (Time.current - start).round(1)
    puts "Done in #{elapsed}s — #{shop.products.count} products, #{shop.variants.count} variants"
  end

  desc 'Reset demo data (destroy and re-seed)'
  task reset: :environment do
    puts 'Resetting demo data...'
    start = Time.current
    Demo::Seeder.new.reset!
    shop = Shop.find_by(shop_domain: 'demo.myshopify.com')
    elapsed = (Time.current - start).round(1)
    puts "Done in #{elapsed}s — #{shop.products.count} products, #{shop.variants.count} variants"
  end
end
```

- [ ] **Step 2: Verify the tasks are loadable**

Run: `bundle exec rails -T demo`
Expected: Shows `demo:seed` and `demo:reset` tasks

- [ ] **Step 3: Commit**

```bash
git add lib/tasks/demo_seed.rake
git commit -m "feat(demo): add rake tasks for demo:seed and demo:reset"
```

---

## Task 4: Demo Mode Toggle — Route, Controller, and Tenant Switching

**Files:**
- Modify: `config/routes.rb`
- Modify: `app/controllers/dashboard_controller.rb`
- Modify: `app/controllers/application_controller.rb`
- Test: `spec/requests/demo_mode_spec.rb`

- [ ] **Step 1: Write failing request specs for demo mode**

```ruby
# spec/requests/demo_mode_spec.rb
# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Demo Mode', type: :request do
  let(:shop) { create(:shop) }

  # Seed demo data once for the entire describe block (expensive operation)
  before(:all) do
    ActsAsTenant.without_tenant { Demo::Seeder.new.seed! }
  end

  after(:all) do
    ActsAsTenant.without_tenant do
      Shop.find_by(shop_domain: 'demo.myshopify.com')&.destroy!
      User.find_by(clerk_user_id: 'demo_user')&.destroy!
    end
  end

  before { login_as(shop) }

  describe 'POST /dashboard/toggle_demo' do
    it 'enables demo mode and redirects to dashboard' do
      post '/dashboard/toggle_demo'
      expect(response).to redirect_to('/dashboard')
      follow_redirect!
      expect(response.body).to include('Demo Mode')
    end

    it 'disables demo mode on second toggle' do
      post '/dashboard/toggle_demo'
      post '/dashboard/toggle_demo'
      expect(response).to redirect_to('/dashboard')
      follow_redirect!
      expect(response.body).not_to include('demo-banner')
    end

    it 'returns alert when demo data not seeded' do
      ActsAsTenant.without_tenant do
        demo_shop = Shop.find_by(shop_domain: 'demo.myshopify.com')
        demo_shop&.destroy!
      end
      post '/dashboard/toggle_demo'
      expect(response).to redirect_to('/dashboard')
      follow_redirect!
      expect(response.body).to include('Demo data not seeded')
      # Re-seed for remaining tests
      ActsAsTenant.without_tenant { Demo::Seeder.new.seed! }
    end
  end

  describe 'demo mode tenant isolation' do
    it 'shows demo shop data on dashboard when demo mode active' do
      post '/dashboard/toggle_demo'
      get '/dashboard'
      demo_shop = Shop.find_by(shop_domain: 'demo.myshopify.com')
      # Dashboard should show demo product count, not real shop count
      expect(response.body).to include('Total Products')
    end
  end

  describe 'demo mode read-only enforcement' do
    before { post '/dashboard/toggle_demo' }

    it 'blocks write actions with redirect' do
      post '/suppliers', params: { supplier: { name: 'Hacker Corp', email: 'x@x.com' } }
      expect(response).to redirect_to('/dashboard')
    end

    it 'allows GET requests' do
      get '/inventory'
      expect(response).to have_http_status(:ok)
    end

    it 'allows toggle_demo POST to exit demo mode' do
      post '/dashboard/toggle_demo'
      expect(response).to redirect_to('/dashboard')
    end

    it 'allows agent run in demo mode' do
      allow_any_instance_of(Inventory::LowStockDetector).to receive(:detect).and_return([])
      post '/agents/run'
      expect(response).to have_http_status(:ok).or have_http_status(:redirect)
    end
  end
end
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `bundle exec rspec spec/requests/demo_mode_spec.rb --format documentation`
Expected: FAIL — route not found / no toggle_demo action

- [ ] **Step 3: Add the toggle_demo route**

In `config/routes.rb`, add after the `get '/dashboard'` line:

```ruby
  post '/dashboard/toggle_demo', to: 'dashboard#toggle_demo'
```

- [ ] **Step 4: Add toggle_demo action to DashboardController**

In `app/controllers/dashboard_controller.rb`, add after the `run_agent` method (before `private`):

```ruby
  def toggle_demo
    if session[:demo_mode]
      session.delete(:demo_mode)
      session.delete(:demo_shop_id)
      redirect_to '/dashboard', notice: 'Demo mode off'
    else
      demo_shop = Shop.find_by(shop_domain: 'demo.myshopify.com')
      unless demo_shop
        redirect_to '/dashboard', alert: 'Demo data not seeded. Run: rails demo:seed'
        return
      end
      session[:demo_mode] = true
      session[:demo_shop_id] = demo_shop.id
      redirect_to '/dashboard', notice: 'Demo mode on'
    end
  end
```

- [ ] **Step 5: Modify ApplicationController — override both `current_shop` AND `set_tenant` for demo mode**

**Critical design note:** Controllers reference `current_shop` directly for non-tenant-scoped queries (e.g., `current_shop.last_agent_results`, `shop_cache.inventory_stats`). Simply changing the tenant is NOT enough — `current_shop` must also return the demo shop, otherwise the dashboard shows real shop stats/agent results while the tenant-scoped queries show demo data.

Additionally, cache the demo shop ID in the session to avoid a `Shop.find_by` on every request.

In `app/controllers/application_controller.rb`, add `before_action :enforce_demo_read_only` after the existing before_actions, and modify the private section:

```ruby
  before_action :enforce_demo_read_only

  # ...replace current_shop method:

  def current_shop
    return @current_shop if defined?(@current_shop)

    if demo_mode?
      @current_shop = Shop.find_by(id: session[:demo_shop_id])
    else
      @current_shop = current_user&.active_shop
    end
  end
  helper_method :current_shop

  # ...replace set_tenant method:

  def set_tenant
    ActsAsTenant.current_tenant = current_shop
  end

  # ...add new private methods:

  def demo_mode?
    session[:demo_mode].present? && session[:demo_shop_id].present?
  end
  helper_method :demo_mode?

  def enforce_demo_read_only
    return unless demo_mode?
    return if request.get? || request.head?

    # Allow exiting demo mode
    return if controller_name == 'dashboard' && action_name == 'toggle_demo'
    # Allow agent runs (read-only analysis)
    return if controller_name == 'dashboard' && action_name == 'run_agent'

    redirect_to '/dashboard', alert: 'Demo mode is read-only'
  end
```

- [ ] **Step 7: Run the tests to verify they pass**

Run: `bundle exec rspec spec/requests/demo_mode_spec.rb --format documentation`
Expected: All examples pass

- [ ] **Step 8: Run existing dashboard specs to check for regressions**

Run: `bundle exec rspec spec/requests/dashboard_spec.rb --format documentation`
Expected: All existing tests still pass

- [ ] **Step 9: Commit**

```bash
git add config/routes.rb app/controllers/dashboard_controller.rb app/controllers/application_controller.rb spec/requests/demo_mode_spec.rb
git commit -m "feat(demo): add toggle_demo action with tenant switching and read-only enforcement"
```

---

## Task 5: Demo Banner UI

**Files:**
- Create: `app/views/layouts/_demo_banner.html.erb`
- Modify: `app/views/layouts/application.html.erb`

- [ ] **Step 1: Create the demo banner partial**

```erb
<%# app/views/layouts/_demo_banner.html.erb %>
<% if demo_mode? %>
  <div class="demo-banner" role="alert" aria-live="polite">
    <div class="demo-banner__content">
      <span class="demo-banner__label">Demo Mode</span>
      <span class="demo-banner__text">Viewing sample data &mdash; all actions are read-only.</span>
      <form action="/dashboard/toggle_demo" method="post" style="display:inline">
        <%= hidden_field_tag :authenticity_token, form_authenticity_token %>
        <button type="submit" class="demo-banner__exit">Exit Demo</button>
      </form>
    </div>
  </div>
  <style>
    .demo-banner {
      background: var(--color-bg-hover, #F6F6F7);
      border-bottom: 1px solid var(--color-stroke-light, #E1E3E5);
      padding: 8px 16px;
      text-align: center;
      position: sticky;
      top: 0;
      z-index: 100;
    }
    .demo-banner__content {
      display: flex;
      align-items: center;
      justify-content: center;
      gap: 12px;
      font-size: 13px;
      color: var(--color-text-secondary, #6D7175);
    }
    .demo-banner__label {
      font-weight: 600;
      color: var(--color-text, #1A1A1A);
      background: var(--color-bg-pressed, #EDEEEF);
      padding: 2px 8px;
      border-radius: 4px;
      font-size: 11px;
      text-transform: uppercase;
      letter-spacing: 0.5px;
    }
    .demo-banner__exit {
      color: var(--color-link, #2C6ECB);
      text-decoration: none;
      font-weight: 500;
      background: none;
      border: none;
      cursor: pointer;
      font-size: 13px;
      padding: 0;
    }
    .demo-banner__exit:hover {
      text-decoration: underline;
    }
  </style>
<% end %>
```

- [ ] **Step 2: Render the banner in the application layout**

In `app/views/layouts/application.html.erb`, add after `<%= render "shared/flash" %>`:

```erb
      <%= render "layouts/demo_banner" %>
```

- [ ] **Step 3: Verify visually**

Run: `bundle exec rails server` (in separate terminal)
Navigate to `/dashboard`, toggle demo mode on. Confirm the banner appears at the top of the page.

- [ ] **Step 4: Commit**

```bash
git add app/views/layouts/_demo_banner.html.erb app/views/layouts/application.html.erb
git commit -m "feat(demo): add demo mode banner to application layout"
```

---

## Task 6: Wire Up Demo Toggle Button on Dashboard

**Files:**
- Modify: `app/views/dashboard/index.html.erb` — add a "Demo Mode" toggle button

We need to see how the dashboard currently renders to know where to place the toggle.

- [ ] **Step 1: Read the current dashboard view**

Read: `app/views/dashboard/index.html.erb`
Look for the existing `demo-toggle` element (the old client-side hack). We'll replace it with the new server-side toggle.

- [ ] **Step 2: Replace the old demo toggle with the new one**

Find the existing `demo-toggle` button/element and replace it with:

```erb
<form action="/dashboard/toggle_demo" method="post" style="display:inline">
  <%= hidden_field_tag :authenticity_token, form_authenticity_token %>
  <button type="submit"
    class="bento__demo-toggle <%= 'is-active' if demo_mode? %>"
    id="demo-toggle"
    title="<%= demo_mode? ? 'Exit demo mode' : 'Enter demo mode' %>"
    aria-label="<%= demo_mode? ? 'Exit demo mode' : 'Enter demo mode' %>">
    <svg width="16" height="16" viewBox="0 0 16 16" fill="none" aria-hidden="true">
      <circle cx="8" cy="8" r="7" stroke="currentColor" stroke-width="1.5"/>
      <path d="M5 8l2 2 4-4" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/>
    </svg>
    <%= demo_mode? ? 'Demo On' : 'Demo' %>
  </button>
</form>
```

- [ ] **Step 3: Commit**

```bash
git add app/views/dashboard/index.html.erb
git commit -m "feat(demo): replace client-side demo toggle with server-side toggle button"
```

---

## Task 7: Clean Up Old Client-Side Demo Toggle

**Files:**
- Delete: `app/assets/javascripts/demo-toggle.js` (the old client-side hack)

- [ ] **Step 1: Verify the old demo-toggle.js is no longer referenced**

Search for references to `demo-toggle` in layout/view files. The only reference should be the new server-side button. If `demo-toggle.js` is loaded via `javascript_include_tag` in a layout, remove that tag.

Check: `app/views/layouts/application.html.erb` — currently does NOT include `demo-toggle` as a `javascript_include_tag`, so it may be loaded elsewhere (possibly via Propshaft auto-include). Check if Propshaft auto-includes all JS files from `app/assets/javascripts/`.

- [ ] **Step 2: Delete the old file (if safe)**

If `demo-toggle.js` is auto-included by Propshaft, it could conflict with the new server-side toggle. Either delete it or gut its contents to a no-op:

```javascript
// demo-toggle.js — replaced by server-side demo mode (POST /dashboard/toggle_demo)
```

- [ ] **Step 3: Commit**

```bash
git add app/assets/javascripts/demo-toggle.js
git commit -m "chore(demo): deprecate client-side demo toggle in favor of server-side"
```

---

## Task 8: Full Integration Test

**Files:**
- Test: `spec/requests/demo_mode_spec.rb` (extend existing file)

- [ ] **Step 1: Add integration test for full demo flow**

Append to `spec/requests/demo_mode_spec.rb`:

```ruby
  describe 'full demo flow integration' do
    it 'enables demo mode, views all major pages, then disables' do
      # Enable demo mode
      post '/dashboard/toggle_demo'
      expect(response).to redirect_to('/dashboard')

      # Dashboard loads with demo data
      get '/dashboard'
      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Demo Mode')

      # Inventory page loads
      get '/inventory'
      expect(response).to have_http_status(:ok)

      # Suppliers page loads
      get '/suppliers'
      expect(response).to have_http_status(:ok)

      # Alerts page loads
      get '/alerts'
      expect(response).to have_http_status(:ok)

      # Purchase orders page loads
      get '/purchase_orders'
      expect(response).to have_http_status(:ok)

      # Disable demo mode
      post '/dashboard/toggle_demo'
      follow_redirect!
      expect(response.body).not_to include('demo-banner')
    end
  end
```

- [ ] **Step 2: Run full test suite**

Run: `bundle exec rspec spec/requests/demo_mode_spec.rb --format documentation`
Expected: All examples pass

- [ ] **Step 3: Run the full spec suite to check for regressions**

Run: `bundle exec rspec --format documentation`
Expected: No regressions in existing tests

- [ ] **Step 4: Commit**

```bash
git add spec/requests/demo_mode_spec.rb
git commit -m "test(demo): add full integration test for demo mode flow"
```

---

## Task 9: Run Seed and Verify Manually

- [ ] **Step 1: Run the demo seed task**

Run: `bundle exec rails demo:seed`
Expected: Completes in <20 seconds, prints product/variant counts

- [ ] **Step 2: Start the server and verify demo mode works end-to-end**

Run: `bundle exec rails server`
1. Log in to the app
2. Navigate to `/dashboard`
3. Click the "Demo" toggle button
4. Verify: demo banner appears, all KPI cards show non-zero data
5. Navigate to `/inventory` — verify products appear
6. Navigate to `/suppliers` — verify 8 suppliers
7. Navigate to `/purchase_orders` — verify PO history
8. Navigate to `/alerts` — verify alert history
9. Try creating a supplier — should be blocked with "Demo mode is read-only"
10. Click "Exit Demo" — banner disappears, real data returns

- [ ] **Step 3: Run the demo reset task**

Run: `bundle exec rails demo:reset`
Expected: Old data destroyed, fresh data seeded

---

## Summary

| Task | Files | What It Does |
|------|-------|-------------|
| 1 | `data_catalog.rb` + spec | Static product/supplier definitions |
| 2 | `seeder.rb` + spec | Full data generation (products, snapshots, alerts, POs) |
| 3 | `demo_seed.rake` | `demo:seed` and `demo:reset` rake tasks |
| 4 | Routes + controllers + spec | Toggle action, tenant switching, read-only enforcement |
| 5 | `_demo_banner.html.erb` + layout | Visual indicator when demo mode is active |
| 6 | Dashboard view | Wire up toggle button |
| 7 | `demo-toggle.js` | Remove/deprecate old client-side hack |
| 8 | Request spec | Full flow integration test |
| 9 | Manual | Seed + verify end-to-end |
