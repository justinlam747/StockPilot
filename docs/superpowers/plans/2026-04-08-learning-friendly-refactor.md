# Learning-Friendly Codebase Refactor — Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make every function in the codebase tell a clear story so a Ruby learner can follow it function-by-function.

**Architecture:** No new patterns — just rename, merge duplicates, move queries to models, add teaching comments, delete dead code. Behavior stays identical.

**Tech Stack:** Ruby on Rails 7.2, PostgreSQL (DISTINCT ON), RSpec

**Spec:** `docs/superpowers/specs/2026-04-08-learning-friendly-refactor-design.md`

---

## Chunk 1: Shared Snapshot Query + Learning Comments on Models

### Task 1: Add `InventorySnapshot.latest_per_variant` class method

This is the foundation — one method replaces 3 copies of the same DISTINCT ON query.

**Files:**
- Modify: `app/models/inventory_snapshot.rb`
- Modify: `spec/models/inventory_snapshot_spec.rb`

- [ ] **Step 1: Write the failing test**

Add to `spec/models/inventory_snapshot_spec.rb`:

```ruby
describe '.latest_per_variant' do
  it 'returns the most recent snapshot for each variant' do
    ActsAsTenant.with_tenant(shop) do
      product = create(:product, shop: shop)
      variant = create(:variant, shop: shop, product: product)

      # Create two snapshots — older one with 10, newer one with 5
      create(:inventory_snapshot, shop: shop, variant: variant, available: 10,
             created_at: 2.hours.ago)
      create(:inventory_snapshot, shop: shop, variant: variant, available: 5,
             created_at: 1.hour.ago)

      results = InventorySnapshot.latest_per_variant(shop_id: shop.id)
      expect(results.length).to eq(1)
      expect(results.first.available).to eq(5) # the newer one
    end
  end

  it 'filters by variant_ids when provided' do
    ActsAsTenant.with_tenant(shop) do
      product = create(:product, shop: shop)
      variant_a = create(:variant, shop: shop, product: product)
      variant_b = create(:variant, shop: shop, product: product)

      create(:inventory_snapshot, shop: shop, variant: variant_a, available: 10)
      create(:inventory_snapshot, shop: shop, variant: variant_b, available: 20)

      results = InventorySnapshot.latest_per_variant(
        shop_id: shop.id, variant_ids: [variant_a.id]
      )
      expect(results.length).to eq(1)
      expect(results.first.variant_id).to eq(variant_a.id)
    end
  end

  it 'selects only requested columns' do
    ActsAsTenant.with_tenant(shop) do
      product = create(:product, shop: shop)
      variant = create(:variant, shop: shop, product: product)
      create(:inventory_snapshot, shop: shop, variant: variant, available: 5,
             on_hand: 8, committed: 3, incoming: 0)

      results = InventorySnapshot.latest_per_variant(
        shop_id: shop.id,
        columns: %w[variant_id available on_hand committed incoming]
      )
      row = results.first
      expect(row.variant_id).to eq(variant.id)
      expect(row.available).to eq(5)
      expect(row.on_hand).to eq(8)
    end
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bundle exec rspec spec/models/inventory_snapshot_spec.rb -e "latest_per_variant"`
Expected: FAIL with "undefined method 'latest_per_variant'"

- [ ] **Step 3: Write the implementation**

Add to `app/models/inventory_snapshot.rb`:

```ruby
# frozen_string_literal: true

# Point-in-time record of a variant's stock levels across all locations.
#
# Each row captures how much inventory a variant has at a moment in time.
# Multiple snapshots per variant build up a history over time.
class InventorySnapshot < ApplicationRecord
  # acts_as_tenant automatically adds "WHERE shop_id = ?" to every query.
  # This prevents one merchant from seeing another merchant's data.
  # Learn more: https://github.com/ErwinM/acts_as_tenant
  acts_as_tenant :shop

  belongs_to :variant

  validates :available, presence: true, numericality: { only_integer: true }
  validates :on_hand, presence: true, numericality: { only_integer: true }
  validates :committed, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :incoming, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  # Returns the most recent snapshot for each variant as an ActiveRecord relation.
  #
  # HOW IT WORKS (PostgreSQL-specific):
  # DISTINCT ON (variant_id) keeps only the first row per variant_id.
  # Combined with ORDER BY variant_id, created_at DESC, "first" means "newest."
  # This gives us the latest stock level for each variant in a single query.
  #
  # WHY A RELATION (not an array):
  # Returning a relation lets callers chain more operations:
  #   .to_sql     -> use as a subquery inside a JOIN
  #   .index_by   -> build a hash lookup { variant_id => snapshot }
  #   .where(...) -> add more filters
  #
  # PARAMETERS:
  #   shop_id:     - which shop's data to query (required for tenant safety)
  #   variant_ids: - optional array to limit which variants to look up
  #   columns:     - which columns to SELECT (default: just variant_id and available)
  #
  # Only these column names are allowed — this prevents SQL injection.
  # Even though all our callers pass hardcoded strings, we validate anyway
  # because it's a good habit: never trust input to a SQL query.
  ALLOWED_COLUMNS = %w[variant_id available on_hand committed incoming created_at].freeze

  def self.latest_per_variant(shop_id:, variant_ids: nil, columns: %w[variant_id available])
    # Validate columns against the whitelist to prevent SQL injection
    invalid_columns = columns - ALLOWED_COLUMNS
    if invalid_columns.any?
      raise ArgumentError, "Invalid columns: #{invalid_columns.join(', ')}. Allowed: #{ALLOWED_COLUMNS.join(', ')}"
    end

    # Start building the query
    scope = select("DISTINCT ON (variant_id) #{columns.join(', ')}")
            .where(shop_id: shop_id)
            .order('variant_id, created_at DESC')

    # If caller only wants specific variants, filter to just those
    scope = scope.where(variant_id: variant_ids) if variant_ids.present?

    scope
  end
end
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bundle exec rspec spec/models/inventory_snapshot_spec.rb -e "latest_per_variant"`
Expected: PASS (all 3 examples)

- [ ] **Step 5: Add `daily_totals` class method for chart data**

Add this test to `spec/models/inventory_snapshot_spec.rb`:

```ruby
describe '.daily_totals' do
  it 'returns a hash of date => total available for the last N days' do
    ActsAsTenant.with_tenant(shop) do
      product = create(:product, shop: shop)
      variant = create(:variant, shop: shop, product: product)

      create(:inventory_snapshot, shop: shop, variant: variant, available: 10,
             created_at: 2.days.ago)
      create(:inventory_snapshot, shop: shop, variant: variant, available: 15,
             created_at: 1.day.ago)

      result = InventorySnapshot.daily_totals(variant_ids: [variant.id], days: 14)

      # Should have 14 entries (one per day), with zeros for days without data
      expect(result.keys.length).to eq(14)
      expect(result[2.days.ago.to_date]).to eq(10)
      expect(result[1.day.ago.to_date]).to eq(15)
      expect(result[5.days.ago.to_date]).to eq(0) # no data = zero
    end
  end
end
```

- [ ] **Step 6: Run test to verify it fails**

Run: `bundle exec rspec spec/models/inventory_snapshot_spec.rb -e "daily_totals"`
Expected: FAIL

- [ ] **Step 7: Implement `daily_totals`**

Add to `app/models/inventory_snapshot.rb`:

```ruby
  # Returns a hash of { Date => total_available } for the last N days.
  #
  # Used by the inventory detail page to draw a stock-level chart.
  # Days with no snapshot data show as zero.
  #
  # HOW IT WORKS:
  # 1. Query the database for daily SUM(available) grouped by date
  # 2. Build a hash with every date in the range (so the chart has no gaps)
  # 3. Fill in the actual values from the query
  #
  def self.daily_totals(variant_ids:, days: 14)
    # Step 1: Query database for actual daily totals
    raw_totals = where(variant_id: variant_ids)
                 .where('created_at >= ?', days.days.ago)
                 .select('DATE(created_at) AS snap_date, SUM(available) AS total_available')
                 .group('DATE(created_at)')
                 .order('snap_date')

    # Step 2: Build a hash with every date initialized to zero
    date_map = {}
    ((days - 1).days.ago.to_date..Date.current).each { |date| date_map[date] = 0 }

    # Step 3: Fill in the real values from the query
    # .each iterates over the query results (each row has snap_date and total_available)
    raw_totals.each { |row| date_map[row.snap_date.to_date] = row.total_available.to_i }

    date_map
  end
```

- [ ] **Step 8: Run test to verify it passes**

Run: `bundle exec rspec spec/models/inventory_snapshot_spec.rb -e "daily_totals"`
Expected: PASS

- [ ] **Step 9: Run full model spec to make sure nothing broke**

Run: `bundle exec rspec spec/models/inventory_snapshot_spec.rb`
Expected: All examples pass

---

### Task 2: Add learning comments to all models

No behavior changes — just add "why/how" comments to teach Ruby/Rails patterns.

**Files:**
- Modify: `app/models/product.rb`
- Modify: `app/models/variant.rb`
- Modify: `app/models/alert.rb`
- Modify: `app/models/shop.rb`
- Modify: `app/models/supplier.rb`
- Modify: `app/models/purchase_order.rb`
- Modify: `app/models/audit_log.rb`

- [ ] **Step 1: Add comments to Product model**

```ruby
# frozen_string_literal: true

# Represents a Shopify product synced from the store.
# Each product has one or more variants (sizes, colors, etc.).
class Product < ApplicationRecord
  # acts_as_tenant automatically adds "WHERE shop_id = ?" to every query.
  # This prevents one merchant from seeing another merchant's data.
  acts_as_tenant :shop

  has_many :variants, dependent: :destroy

  validates :shopify_product_id, presence: true, if: -> { source == 'shopify' }
  validates :title, presence: true, length: { maximum: 500 }

  # scope = a named query shortcut. Instead of writing
  #   Product.where(deleted_at: nil) everywhere,
  #   you can write Product.active
  # Think of it as a reusable filter you define once and use many times.
  scope :active, -> { where(deleted_at: nil) }
end
```

- [ ] **Step 2: Add comments to Variant model**

```ruby
# frozen_string_literal: true

# A specific SKU/option combination of a product.
# Example: "Blue T-Shirt, Size M" is one variant of the "T-Shirt" product.
class Variant < ApplicationRecord
  acts_as_tenant :shop

  # attr_accessor creates a getter/setter that lives only in memory (not in the database).
  # We use this to temporarily attach the latest stock level to a variant
  # so the view can display it without loading the full snapshot history.
  attr_accessor :current_stock

  belongs_to :product
  belongs_to :supplier, optional: true
  has_many :inventory_snapshots, dependent: :destroy
  has_many :alerts, dependent: :destroy
  # dependent: :restrict_with_error prevents deletion if line items exist,
  # raising an error instead of silently deleting related purchase order data.
  has_many :purchase_order_line_items, dependent: :restrict_with_error

  validates :shopify_variant_id, presence: true, if: -> { source == 'shopify' }
  validates :price, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :low_stock_threshold, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
end
```

- [ ] **Step 3: Add comments to Shop model**

```ruby
# frozen_string_literal: true

# A Shopify merchant store — the tenant root for all scoped data.
# Every other model (products, variants, alerts, etc.) belongs to a Shop.
class Shop < ApplicationRecord
  # encrypts uses Rails 7's built-in encryption to store the access_token
  # as ciphertext in the database. When you read shop.access_token in Ruby,
  # Rails automatically decrypts it. This protects tokens if the database
  # is ever compromised. Requires RAILS_MASTER_KEY to decrypt.
  encrypts :access_token

  has_many :products, dependent: :destroy
  has_many :variants, dependent: :destroy
  has_many :inventory_snapshots, dependent: :destroy
  has_many :suppliers, dependent: :destroy
  has_many :alerts, dependent: :destroy
  has_many :purchase_orders, dependent: :destroy
  has_many :audit_logs, dependent: :destroy

  DOMAIN_FORMAT = /\A[a-z0-9-]+\.myshopify\.com\z/i

  validates :shop_domain, presence: true, uniqueness: true,
                          format: { with: DOMAIN_FORMAT, message: 'must be a valid myshopify.com domain' }
  validates :access_token, presence: true, unless: :uninstalled?

  scope :active, -> { where(uninstalled_at: nil) }

  def uninstalled?
    uninstalled_at.present?
  end

  # Settings are stored as a JSON hash in the database.
  # These helper methods provide named access with sensible defaults.
  def timezone
    settings['timezone'] || 'America/Toronto'
  end

  def low_stock_threshold
    settings['low_stock_threshold'] || 10
  end

  def alert_email
    settings['alert_email']
  end

  def update_setting(key, value)
    self.settings = settings.merge(key => value)
    save!
  end
end
```

- [ ] **Step 4: Add comments to Alert, Supplier, PurchaseOrder, AuditLog models**

For Alert — add `acts_as_tenant` comment (same as others).

For AuditLog:
```ruby
  # readonly? returning true for persisted records makes Rails raise an error
  # if anyone tries to update or delete an audit log after it's saved.
  # This ensures audit logs are immutable — once created, they can never be changed.
  def readonly?
    persisted?
  end
```

For PurchaseOrder:
```ruby
  # before_validation runs this method automatically before Rails checks validations.
  # on: :create means it only runs when creating a new record, not when updating.
  # This sets sensible defaults so callers don't have to remember to set them.
  before_validation :set_defaults, on: :create
```

- [ ] **Step 5: Run all model specs**

Run: `bundle exec rspec spec/models/`
Expected: All pass (comments don't change behavior)

- [ ] **Step 6: Commit**

```bash
git add app/models/ spec/models/inventory_snapshot_spec.rb
git commit -m "refactor: add shared InventorySnapshot.latest_per_variant + learning comments on models

Add a reusable class method that replaces 3 copies of the same DISTINCT ON
query. Add daily_totals for chart data. Add teaching comments explaining
Ruby/Rails patterns (acts_as_tenant, encrypts, scope, attr_accessor, etc.)."
```

---

## Chunk 2: Refactor Persister — Merge Duplicate Paths

### Task 3: Consolidate Persister into normalize-then-save

**Files:**
- Modify: `app/services/inventory/persister.rb`
- Modify: `spec/services/inventory/persister_spec.rb`
- Modify: `app/controllers/webhooks_controller.rb` (caller update)
- Modify: `spec/concurrency/race_conditions_spec.rb` (caller update)

- [ ] **Step 1: Update persister spec for new `source:` keyword**

In `spec/services/inventory/persister_spec.rb`, update the `#upsert_single_product` tests:

```ruby
  describe '#upsert_single_product' do
    it 'creates a product from webhook REST payload' do
      webhook_data = {
        'id' => 333,
        'title' => 'Webhook Product',
        'product_type' => 'Gadget',
        'vendor' => 'WebhookCo',
        'status' => 'active',
        'variants' => [
          { 'id' => 444, 'sku' => 'WH-001', 'title' => 'Small', 'price' => '9.99' }
        ]
      }

      ActsAsTenant.with_tenant(shop) do
        expect { persister.upsert_single_product(webhook_data, source: :webhook) }
          .to change { Product.count }.by(1)
      end
    end

    it 'updates existing product without creating duplicates' do
      ActsAsTenant.with_tenant(shop) do
        create(:product, shop: shop, shopify_product_id: '555', title: 'Old Webhook Title')

        webhook_data = {
          'id' => 555,
          'title' => 'Updated Webhook Title',
          'product_type' => 'Gadget',
          'vendor' => 'WebhookCo',
          'status' => 'active',
          'variants' => [
            { 'id' => 666, 'sku' => 'WH-002', 'title' => 'Medium', 'price' => '14.99' }
          ]
        }

        expect { persister.upsert_single_product(webhook_data, source: :webhook) }
          .not_to(change { Product.count })
        expect(Product.find_by(shopify_product_id: '555').title).to eq('Updated Webhook Title')
      end
    end
  end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bundle exec rspec spec/services/inventory/persister_spec.rb -e "upsert_single_product"`
Expected: FAIL (wrong number of arguments)

- [ ] **Step 3: Rewrite the Persister with one path**

Replace `app/services/inventory/persister.rb` with:

```ruby
# frozen_string_literal: true

module Inventory
  # Saves products and variants from Shopify into our database.
  #
  # Shopify sends us product data in two different formats:
  #   1. GraphQL batch sync — uses keys like 'legacyResourceId', 'productType'
  #   2. Webhook REST payload — uses keys like 'id', 'product_type'
  #
  # Instead of writing two separate save functions (one per format),
  # we NORMALIZE the data first into a common shape, then save it once.
  # This means there's only one "save" path to understand.
  #
  class Persister
    def initialize(shop)
      @shop = shop
      @cache = Cache::ShopCache.new(shop)
    end

    # Called by InventorySyncJob — saves a batch of products from GraphQL.
    def upsert(data)
      data[:products].each do |product_node|
        product = upsert_single_product(product_node, source: :graphql)
        @cache.write_product(product.reload) if product
      end
      @cache.invalidate_inventory
    end

    # Called by WebhooksController — saves one product from a webhook.
    # Also called by upsert above for each product in a batch.
    #
    # The source: keyword tells normalize which format the data is in:
    #   source: :webhook  -> REST format  (keys like 'id', 'product_type')
    #   source: :graphql  -> GraphQL format (keys like 'legacyResourceId', 'productType')
    #
    def upsert_single_product(raw_data, source:)
      normalized = normalize_product_data(raw_data, source: source)
      product = find_or_initialize_product(normalized[:shopify_id])
      save_product(product, normalized)
      save_variants(product, normalized[:variants])
      product
    end

    private

    # ---- Normalize: turn either format into the same hash shape ----

    # Takes raw Shopify data and returns a clean hash with consistent keys.
    #
    # Ruby learning note: Hash#merge and conditional logic let us handle
    # different API formats without duplicating save logic.
    #
    def normalize_product_data(raw_data, source:)
      case source
      when :webhook  then normalize_webhook_product(raw_data)
      when :graphql  then normalize_graphql_product(raw_data)
      else raise ArgumentError, "Unknown source: #{source}. Expected :webhook or :graphql"
      end
    end

    def normalize_webhook_product(data)
      {
        shopify_id: data['id'].to_s,
        title: data['title'],
        product_type: data['product_type'] || data['productType'],
        vendor: data['vendor'],
        status: (data['status'] || 'active').downcase,
        image_url: nil,
        variants: (data['variants'] || []).map { |v| normalize_webhook_variant(v) }
      }
    end

    def normalize_graphql_product(node)
      {
        shopify_id: node['legacyResourceId'].to_s,
        title: node['title'],
        product_type: node['productType'],
        vendor: node['vendor'],
        status: node['status']&.downcase || 'active',
        image_url: node.dig('featuredMedia', 'preview', 'image', 'url'),
        variants: (node.dig('variants', 'nodes') || []).map { |v| normalize_graphql_variant(v) }
      }
    end

    def normalize_webhook_variant(data)
      {
        shopify_id: data['id'].to_s,
        sku: data['sku'],
        title: data['title'],
        price: data['price'].to_f
      }
    end

    def normalize_graphql_variant(node)
      {
        shopify_id: node['legacyResourceId'].to_s,
        sku: node['sku'],
        title: node['title'],
        price: node['price'].to_f
      }
    end

    # ---- Save: one path for both formats ----

    # find_or_initialize_by is an ActiveRecord method that either:
    #   - finds an existing record matching the condition, OR
    #   - creates a new (unsaved) record with that value pre-filled.
    # This prevents duplicate products when we sync the same data twice.
    def find_or_initialize_product(shopify_id)
      Product.find_or_initialize_by(shopify_product_id: shopify_id)
    end

    def save_product(product, normalized)
      product.assign_attributes(
        title: normalized[:title],
        product_type: normalized[:product_type],
        vendor: normalized[:vendor],
        status: normalized[:status],
        image_url: normalized[:image_url],
        deleted_at: nil,
        synced_at: Time.current
      )
      product.save!
    end

    def save_variants(product, normalized_variants)
      normalized_variants.each do |variant_data|
        variant = Variant.find_or_initialize_by(shopify_variant_id: variant_data[:shopify_id])
        variant.assign_attributes(
          product: product,
          sku: variant_data[:sku],
          title: variant_data[:title],
          price: variant_data[:price]
        )
        variant.save!
      end
    end
  end
end
```

- [ ] **Step 4: Run persister specs to verify they pass**

Run: `bundle exec rspec spec/services/inventory/persister_spec.rb`
Expected: All pass

- [ ] **Step 5: Update WebhooksController caller**

In `app/controllers/webhooks_controller.rb`, change line 53:

```ruby
  # Before:
  Inventory::Persister.new(shop).upsert_single_product(JSON.parse(webhook_body))

  # After:
  Inventory::Persister.new(shop).upsert_single_product(JSON.parse(webhook_body), source: :webhook)
```

- [ ] **Step 6: Update race_conditions_spec.rb caller**

In `spec/concurrency/race_conditions_spec.rb`, update lines 202 and 206 to pass `source: :webhook`:

```ruby
  # Before:
  persister.upsert_single_product(shopify_data)

  # After:
  persister.upsert_single_product(shopify_data, source: :webhook)
```

- [ ] **Step 7: Run all affected specs**

Run: `bundle exec rspec spec/services/inventory/persister_spec.rb spec/concurrency/race_conditions_spec.rb spec/requests/webhooks_html_spec.rb spec/integration/full_sync_pipeline_spec.rb spec/jobs/inventory_sync_job_spec.rb`
Expected: All pass

- [ ] **Step 8: Commit**

```bash
git add app/services/inventory/persister.rb app/controllers/webhooks_controller.rb spec/services/inventory/persister_spec.rb spec/concurrency/race_conditions_spec.rb
git commit -m "refactor: merge Persister duplicate paths into normalize-then-save

Two nearly identical code paths (webhook vs GraphQL) are now one:
normalize the data format first, then save through a single path.
Easier to follow and learn from."
```

---

## Chunk 3: Slim InventoryController — Move Queries to Models

### Task 4: Move filtering/search scopes to Product model

**Files:**
- Modify: `app/models/product.rb`
- Modify: `spec/models/product_spec.rb`

- [ ] **Step 1: Write failing tests for Product scopes**

Add to `spec/models/product_spec.rb`:

```ruby
describe '.with_low_stock' do
  let(:shop) { create(:shop, settings: { 'low_stock_threshold' => 10 }) }

  it 'returns products where latest snapshot available is above 0 but below threshold' do
    ActsAsTenant.with_tenant(shop) do
      product = create(:product, shop: shop)
      variant = create(:variant, shop: shop, product: product)
      create(:inventory_snapshot, shop: shop, variant: variant, available: 5)

      results = Product.with_low_stock(shop)
      expect(results).to include(product)
    end
  end

  it 'excludes products with stock above threshold' do
    ActsAsTenant.with_tenant(shop) do
      product = create(:product, shop: shop)
      variant = create(:variant, shop: shop, product: product)
      create(:inventory_snapshot, shop: shop, variant: variant, available: 50)

      results = Product.with_low_stock(shop)
      expect(results).not_to include(product)
    end
  end
end

describe '.out_of_stock_only' do
  let(:shop) { create(:shop) }

  it 'returns products where latest snapshot available is zero' do
    ActsAsTenant.with_tenant(shop) do
      product = create(:product, shop: shop)
      variant = create(:variant, shop: shop, product: product)
      create(:inventory_snapshot, shop: shop, variant: variant, available: 0)

      results = Product.out_of_stock_only(shop)
      expect(results).to include(product)
    end
  end
end

describe '.search_by_title_or_sku' do
  let(:shop) { create(:shop) }

  it 'finds products by title' do
    ActsAsTenant.with_tenant(shop) do
      product = create(:product, shop: shop, title: 'Blue Widget')
      create(:variant, shop: shop, product: product)

      results = Product.search_by_title_or_sku('blue')
      expect(results).to include(product)
    end
  end

  it 'finds products by variant SKU' do
    ActsAsTenant.with_tenant(shop) do
      product = create(:product, shop: shop, title: 'Something')
      create(:variant, shop: shop, product: product, sku: 'BLU-001')

      results = Product.search_by_title_or_sku('BLU')
      expect(results).to include(product)
    end
  end
end
```

- [ ] **Step 2: Run to verify failure**

Run: `bundle exec rspec spec/models/product_spec.rb -e "with_low_stock|out_of_stock_only|search_by_title_or_sku"`
Expected: FAIL

- [ ] **Step 3: Implement scopes on Product model**

Add to `app/models/product.rb`:

```ruby
# frozen_string_literal: true

# Represents a Shopify product synced from the store.
# Each product has one or more variants (sizes, colors, etc.).
class Product < ApplicationRecord
  acts_as_tenant :shop

  has_many :variants, dependent: :destroy

  validates :shopify_product_id, presence: true, if: -> { source == 'shopify' }
  validates :title, presence: true, length: { maximum: 500 }

  scope :active, -> { where(deleted_at: nil) }

  # Returns products that have at least one variant with low stock.
  # "Low stock" means: available > 0 but below the shop's threshold.
  #
  # How this works:
  # 1. We JOIN products to their variants
  # 2. We JOIN variants to their latest inventory snapshot
  # 3. We filter to snapshots where available is between 1 and threshold
  #
  def self.with_low_stock(shop)
    threshold = shop.low_stock_threshold
    latest_sql = InventorySnapshot.latest_per_variant(shop_id: shop.id).to_sql

    joins(:variants)
      .joins("INNER JOIN (#{latest_sql}) AS latest_snap ON latest_snap.variant_id = variants.id")
      .where('latest_snap.available > 0 AND latest_snap.available < ?', threshold)
      .distinct
  end

  # Returns products that have at least one variant with zero stock.
  def self.out_of_stock_only(shop)
    latest_sql = InventorySnapshot.latest_per_variant(shop_id: shop.id).to_sql

    joins(:variants)
      .joins("INNER JOIN (#{latest_sql}) AS latest_snap ON latest_snap.variant_id = variants.id")
      .where('latest_snap.available = 0')
      .distinct
  end

  # Searches products by title OR any variant's SKU (case-insensitive).
  #
  # sanitize_sql_like escapes special SQL characters (%, _) in the search term
  # so users can search for literal "100%" without it matching everything.
  #
  def self.search_by_title_or_sku(query)
    return all if query.blank?

    term = "%#{sanitize_sql_like(query)}%"
    left_joins(:variants)
      .where('products.title ILIKE :q OR variants.sku ILIKE :q', q: term)
      .distinct
  end
end
```

- [ ] **Step 4: Run product specs**

Run: `bundle exec rspec spec/models/product_spec.rb`
Expected: All pass

- [ ] **Step 5: Commit**

```bash
git add app/models/product.rb spec/models/product_spec.rb
git commit -m "refactor: move inventory filter scopes to Product model

Products now have .with_low_stock, .out_of_stock_only, and
.search_by_title_or_sku scopes. These use the shared
InventorySnapshot.latest_per_variant method."
```

---

### Task 5: Slim down InventoryController

**Files:**
- Modify: `app/controllers/inventory_controller.rb`
- Modify: `spec/requests/inventory_html_spec.rb` (verify still passes)

- [ ] **Step 1: Rewrite InventoryController**

Replace `app/controllers/inventory_controller.rb`:

```ruby
# frozen_string_literal: true

# Displays paginated inventory with filtering by stock status and search.
#
# This controller handles HTTP concerns only:
#   - Read URL parameters (filter, search, sort, page)
#   - Call model scopes to get the right data
#   - Paginate and render
#
# The actual query logic lives in the models (Product, InventorySnapshot)
# where Rails developers expect to find it.
#
class InventoryController < ApplicationController
  before_action :require_shop!

  def index
    load_inventory_stats
    @products = find_filtered_products
    attach_current_stock_to_variants(@products)

    return unless request.headers['HX-Request']

    partial = params[:view] == 'table' ? 'table' : 'grid'
    render partial: partial, locals: { products: @products }
  end

  def show
    @product = Product.includes(variants: %i[inventory_snapshots supplier]).find(params[:id])
    @snapshot_data = load_chart_data_for_product(@product)
  end

  private

  # Builds the product list by chaining model scopes.
  # Each scope is defined on the Product model — look there for the SQL.
  def find_filtered_products
    scope = Product.includes(:variants)
    scope = apply_stock_filter(scope)
    scope = apply_search(scope)
    scope = apply_sort(scope)
    scope.page(params[:page]).per(24)
  end

  def apply_stock_filter(scope)
    case params[:filter]
    when 'low_stock'    then scope.with_low_stock(current_shop)
    when 'out_of_stock' then scope.out_of_stock_only(current_shop)
    else scope
    end
  end

  def apply_search(scope)
    return scope unless params[:q].present?

    scope.search_by_title_or_sku(params[:q])
  end

  def apply_sort(scope)
    case params[:sort]
    when 'title_desc' then scope.order(title: :desc)
    when 'newest'     then scope.order(created_at: :desc)
    when 'vendor'     then scope.order(:vendor, :title)
    else scope.order(:title)
    end
  end

  def load_inventory_stats
    stats = shop_cache.inventory_stats
    @total_variants = Variant.where(shop_id: current_shop.id).count
    @low_stock = stats[:low_stock]
    @out_of_stock = stats[:out_of_stock]
    @healthy_products = [stats[:total_products] - @low_stock - @out_of_stock, 0].max
  end

  # Sets variant.current_stock on each variant so the view can display
  # stock levels without loading the full snapshot history.
  #
  # Uses the shared InventorySnapshot.latest_per_variant method.
  # index_by turns the array into a hash: { variant_id => snapshot }
  # so we can look up each variant's stock in O(1) time.
  #
  def attach_current_stock_to_variants(products)
    all_variants = products.flat_map { |p| p.variants.to_a }
    return if all_variants.empty?

    variant_ids = all_variants.map(&:id)
    stock_map = InventorySnapshot.latest_per_variant(
      shop_id: current_shop.id, variant_ids: variant_ids
    ).index_by(&:variant_id)

    all_variants.each { |v| v.current_stock = stock_map[v.id]&.available || 0 }
  end

  # Loads 14 days of chart data using InventorySnapshot.daily_totals.
  def load_chart_data_for_product(product)
    variant_ids = product.variants.map(&:id)
    return {} if variant_ids.empty?

    InventorySnapshot.daily_totals(variant_ids: variant_ids, days: 14)
  end
end
```

- [ ] **Step 2: Run inventory request specs**

Run: `bundle exec rspec spec/requests/inventory_html_spec.rb`
Expected: All pass

- [ ] **Step 3: Run full test suite to check for regressions**

Run: `bundle exec rspec spec/`
Expected: All pass

- [ ] **Step 4: Commit**

```bash
git add app/controllers/inventory_controller.rb
git commit -m "refactor: slim InventoryController from 128 to ~80 lines

Move SQL query logic to model scopes (Product.with_low_stock, etc.)
and use shared InventorySnapshot.latest_per_variant method.
Controller now handles only HTTP concerns."
```

---

## Chunk 4: DashboardController + ShopCache + WeeklyGenerator Fixes

### Task 6: Fix DashboardController hardcoded threshold

**Files:**
- Modify: `app/controllers/dashboard_controller.rb`

- [ ] **Step 1: Rewrite DashboardController**

```ruby
# frozen_string_literal: true

# Renders the merchant dashboard with inventory stats and trend arrows.
class DashboardController < ApplicationController
  def index
    unless current_shop
      @show_connect_banner = true
      return
    end

    load_dashboard_stats
    load_trends
    @recent_alerts = Alert.includes(variant: :product).order(created_at: :desc).limit(10)
  end

  private

  def load_dashboard_stats
    stats = shop_cache.inventory_stats
    @total_products = stats[:total_products]
    @low_stock = stats[:low_stock]
    @out_of_stock = stats[:out_of_stock]
    @pending_pos = stats[:pending_pos]
    @total_suppliers = Supplier.where(shop_id: current_shop.id).count
    @total_alerts = Alert.where(shop_id: current_shop.id).count
    @total_variants = Variant.where(shop_id: current_shop.id).count
    @healthy_products = [@total_products - @low_stock - @out_of_stock, 0].max
    @health_pct = @total_products.positive? ? ((@healthy_products.to_f / @total_products) * 100).round : 0
    @sent_pos = PurchaseOrder.where(shop_id: current_shop.id, status: 'sent').count
    @alerts_today = Alert.where(shop_id: current_shop.id)
                        .where('created_at >= ?', Time.current.beginning_of_day).count
    @avg_variants_per_product = @total_products.positive? ? (@total_variants.to_f / @total_products).round(1) : 0
  end

  def load_trends
    @trends = compute_trends
  end

  # Compares today's counts to yesterday's counts to show up/down/flat arrows.
  def compute_trends
    snapshots = InventorySnapshot.where(shop_id: current_shop.id)
                                 .where('created_at < ?', 24.hours.ago)
    return default_trends unless snapshots.exists?

    prev = counts_from_yesterday(snapshots)
    {
      total_products: trend_direction(@total_products, prev[:total]),
      low_stock: trend_direction(@low_stock, prev[:low]),
      out_of_stock: trend_direction(@out_of_stock, prev[:out]),
      pending_pos: :flat
    }
  end

  # Counts stock levels from yesterday's snapshots for trend comparison.
  # Uses the shop's configured threshold instead of a hardcoded value.
  def counts_from_yesterday(snapshots)
    threshold = current_shop.low_stock_threshold
    prev_total = Product.where(shop_id: current_shop.id)
                        .where('created_at < ?', 24.hours.ago).count
    {
      total: prev_total.zero? ? @total_products : prev_total,
      low: snapshots.where('available > 0 AND available <= ?', threshold).count,
      out: snapshots.where('available <= 0').count
    }
  end

  def default_trends
    { total_products: :flat, low_stock: :flat, out_of_stock: :flat, pending_pos: :flat }
  end

  def trend_direction(current, previous)
    return :flat if current == previous

    current > previous ? :up : :down
  end
end
```

- [ ] **Step 2: Run dashboard specs**

Run: `bundle exec rspec spec/requests/dashboard_spec.rb`
Expected: All pass

- [ ] **Step 3: Commit**

```bash
git add app/controllers/dashboard_controller.rb
git commit -m "refactor: fix hardcoded threshold in DashboardController

Use current_shop.low_stock_threshold instead of hardcoded 10.
Rename previous_counts to counts_from_yesterday for clarity."
```

---

### Task 7: Optimize ShopCache — lightweight count instead of full detection

**Files:**
- Modify: `app/models/inventory_snapshot.rb`
- Modify: `app/services/cache/shop_cache.rb`
- Modify: `spec/services/cache/shop_cache_spec.rb`

- [ ] **Step 1: Add `count_by_stock_status` test to InventorySnapshot spec**

```ruby
describe '.count_by_stock_status' do
  it 'returns low_stock and out_of_stock counts' do
    ActsAsTenant.with_tenant(shop) do
      product = create(:product, shop: shop)

      # Low stock variant (available between 1 and threshold)
      low_variant = create(:variant, shop: shop, product: product)
      create(:inventory_snapshot, shop: shop, variant: low_variant, available: 3)

      # Out of stock variant
      oos_variant = create(:variant, shop: shop, product: product)
      create(:inventory_snapshot, shop: shop, variant: oos_variant, available: 0)

      # Healthy variant (above threshold)
      ok_variant = create(:variant, shop: shop, product: product)
      create(:inventory_snapshot, shop: shop, variant: ok_variant, available: 50)

      counts = InventorySnapshot.count_by_stock_status(shop)
      expect(counts[:low_stock]).to eq(1)
      expect(counts[:out_of_stock]).to eq(1)
    end
  end
end
```

- [ ] **Step 2: Run to verify failure**

Run: `bundle exec rspec spec/models/inventory_snapshot_spec.rb -e "count_by_stock_status"`
Expected: FAIL

- [ ] **Step 3: Implement `count_by_stock_status`**

Add to `app/models/inventory_snapshot.rb`:

```ruby
  # Returns { low_stock: N, out_of_stock: N } using a lightweight COUNT query.
  #
  # This is much faster than LowStockDetector.detect which loads full variant
  # objects. Use this when you only need the numbers (e.g., for dashboard stats).
  # Use LowStockDetector.detect when you need the actual variant records
  # (e.g., for creating alert notifications).
  #
  def self.count_by_stock_status(shop)
    threshold = shop.low_stock_threshold
    latest = latest_per_variant(shop_id: shop.id)

    # We wrap our latest_per_variant query as a subquery and count from it.
    # This avoids loading all the rows into Ruby — the database does the counting.
    #
    # We use sanitize_sql_array to safely inject the threshold value into SQL.
    # This prevents SQL injection — never interpolate values directly into SQL strings.
    #
    count_sql = sanitize_sql_array([
      "SELECT
         COUNT(*) FILTER (WHERE available > 0 AND available < ?) AS low_stock,
         COUNT(*) FILTER (WHERE available <= 0) AS out_of_stock
       FROM (%s) AS latest_snapshots",
      threshold
    ])
    # Replace the %s placeholder with the subquery SQL (which comes from ActiveRecord, so it's safe)
    count_sql = count_sql.sub('%s', latest.to_sql)

    rows = ActiveRecord::Base.connection.select_one(count_sql)

    {
      low_stock: rows['low_stock'].to_i,
      out_of_stock: rows['out_of_stock'].to_i
    }
  end
```

- [ ] **Step 4: Run to verify pass**

Run: `bundle exec rspec spec/models/inventory_snapshot_spec.rb -e "count_by_stock_status"`
Expected: PASS

- [ ] **Step 5: Update ShopCache to use lightweight counts**

In `app/services/cache/shop_cache.rb`, update `build_inventory_stats`:

```ruby
    # Builds dashboard stats using a fast COUNT query instead of loading
    # all flagged variants. Much cheaper when we only need numbers.
    def build_inventory_stats
      counts = InventorySnapshot.count_by_stock_status(@shop)
      {
        total_products: Product.where(shop_id: @shop.id).active.count,
        low_stock: counts[:low_stock],
        out_of_stock: counts[:out_of_stock],
        pending_pos: PurchaseOrder.where(shop_id: @shop.id, status: 'draft').count
      }
    end
```

Also add caching strategy comments at the top of the class:

```ruby
  # Per-shop caching layer for products, suppliers, and inventory stats.
  #
  # CACHING STRATEGIES USED:
  #
  # 1. Write-through (products, suppliers):
  #    When we save a product/supplier, we immediately update the cache too.
  #    This keeps the cache fresh without waiting for it to expire.
  #
  # 2. Cache-aside with short TTL (inventory stats):
  #    We read from cache first. If it's expired (every 2 minutes),
  #    we query the database, save the result to cache, and return it.
  #    Short TTL because inventory changes frequently.
  #
  # 3. Lazy load (products/suppliers lists):
  #    We only query the database when someone actually asks for the data.
  #    The result is cached for 6-12 hours since these change less often.
  #
```

- [ ] **Step 6: Run cache specs**

Run: `bundle exec rspec spec/services/cache/shop_cache_spec.rb`
Expected: All pass

- [ ] **Step 7: Commit**

```bash
git add app/models/inventory_snapshot.rb spec/models/inventory_snapshot_spec.rb app/services/cache/shop_cache.rb
git commit -m "perf: use lightweight COUNT for dashboard stats instead of full detection

ShopCache.build_inventory_stats now uses InventorySnapshot.count_by_stock_status
(a single SQL COUNT query) instead of loading all flagged variants through
LowStockDetector. Much faster for the dashboard's 2-minute cache cycle."
```

---

### Task 8: Memoize LowStockDetector call in WeeklyGenerator

**Files:**
- Modify: `app/services/reports/weekly_generator.rb`

- [ ] **Step 1: Add memoization**

In `app/services/reports/weekly_generator.rb`, replace the two separate calls with one memoized call:

```ruby
    def low_sku_count
      flagged_variants.size
    end

    def reorder_suggestions
      grouped = group_by_supplier(flagged_variants)
      suppliers = Supplier.where(id: grouped.keys).index_by(&:id)
      grouped.map { |sid, variants| format_suggestion(suppliers[sid], variants) }
    end

    # Memoizes the result of LowStockDetector so it only runs once per report.
    # The ||= operator means: "if @flagged_variants is nil, compute it; otherwise reuse it."
    # This avoids running the expensive DISTINCT ON query twice.
    def flagged_variants
      @flagged_variants ||= Inventory::LowStockDetector.new(@shop).detect
    end
```

- [ ] **Step 2: Run weekly generator specs**

Run: `bundle exec rspec spec/services/reports/weekly_generator_spec.rb`
Expected: All pass

- [ ] **Step 3: Commit**

```bash
git add app/services/reports/weekly_generator.rb
git commit -m "perf: memoize LowStockDetector call in WeeklyGenerator

Was calling detect twice per report (once for low_sku_count, once for
reorder_suggestions). Now computed once and reused via ||= memoization."
```

---

## Chunk 5: Update LowStockDetector to Use Shared Query + Rename Methods Across Codebase

### Task 9: Update LowStockDetector to use shared `latest_per_variant`

**Files:**
- Modify: `app/services/inventory/low_stock_detector.rb`

- [ ] **Step 1: Refactor LowStockDetector**

```ruby
# frozen_string_literal: true

module Inventory
  # Identifies variants below their low-stock or out-of-stock thresholds.
  #
  # Used by:
  #   - InventorySyncJob (to trigger alerts for variants that need restocking)
  #   - WeeklyGenerator (to list which SKUs need reordering)
  #
  # For just counting low/out-of-stock variants (without loading them),
  # use InventorySnapshot.count_by_stock_status instead — it's much faster.
  #
  class LowStockDetector
    def initialize(shop)
      @shop = shop
    end

    def detect
      # filter_map is like .map but automatically removes nil results.
      # evaluate_variant returns nil for healthy variants, so they get skipped.
      variants_with_latest_stock.filter_map { |variant| evaluate_variant(variant) }
    end

    private

    def variants_with_latest_stock
      # Use the shared latest_per_variant query from InventorySnapshot.
      # We need all 4 stock columns, not just 'available'.
      latest_sql = InventorySnapshot.latest_per_variant(
        shop_id: @shop.id,
        columns: %w[variant_id available on_hand committed incoming]
      ).to_sql

      join_sql = Arel.sql("INNER JOIN (#{latest_sql}) latest ON latest.variant_id = variants.id")
      Variant.joins(:product).joins(join_sql)
             .where(products: { deleted_at: nil, shop_id: @shop.id })
             .select('variants.*', *snapshot_columns)
    end

    def snapshot_columns
      %w[available on_hand committed incoming].map { |col| "latest.#{col} AS latest_#{col}" }
    end

    def evaluate_variant(variant)
      available = variant.latest_available.to_i
      on_hand = variant.latest_on_hand.to_i
      threshold = variant.low_stock_threshold || @shop.low_stock_threshold
      status = determine_stock_status(available, threshold)
      return if status == :ok

      { variant: variant, available: available, on_hand: on_hand,
        status: status, threshold: threshold }
    end

    # Renamed from stock_status to avoid confusion with the status field on models.
    def determine_stock_status(available, threshold)
      if available <= 0
        :out_of_stock
      elsif available < threshold
        :low_stock
      else
        :ok
      end
    end
  end
end
```

- [ ] **Step 2: Run detector specs**

Run: `bundle exec rspec spec/services/inventory/low_stock_detector_spec.rb`
Expected: All pass

- [ ] **Step 3: Commit**

```bash
git add app/services/inventory/low_stock_detector.rb
git commit -m "refactor: use shared InventorySnapshot.latest_per_variant in LowStockDetector

Replaces the inline DISTINCT ON SQL with the shared model method.
One definition of the 'latest snapshot per variant' query."
```

---

### Task 10: Rename methods across services

**Files:**
- Modify: `app/services/inventory/snapshotter.rb`
- Modify: `app/services/notifications/alert_sender.rb`
- Modify: `app/services/shopify/graphql_client.rb`
- Modify: `app/services/shopify/inventory_fetcher.rb`
- Modify: `app/services/shopify/webhook_registrar.rb`
- Modify: `app/services/reports/weekly_generator.rb`
- Modify: `app/controllers/application_controller.rb`
- Modify: `app/controllers/landing_controller.rb`
- Modify: `app/jobs/inventory_sync_job.rb`
- Modify: Multiple spec files (callers of renamed methods)

- [ ] **Step 1: Rename Snapshotter methods**

In `app/services/inventory/snapshotter.rb`:
- `snapshot` -> `create_snapshots_from_shopify_data`
- `build_snapshot_rows` -> `build_snapshot_rows_for_all_products`
- `build_variant_row` -> `build_one_snapshot_row`

Add comment on `insert_all`:
```ruby
      # insert_all is a bulk insert — it sends one SQL INSERT with all rows
      # instead of saving each row individually. Much faster when you have
      # many rows to save at once (e.g., one per variant per sync).
      InventorySnapshot.insert_all(rows) if rows.any?
```

- [ ] **Step 2: Rename AlertSender methods**

In `app/services/notifications/alert_sender.rb`:
- `send_low_stock_alerts` -> `create_alerts_and_notify`
- `filter_new_alerts` -> `remove_already_alerted_today`

- [ ] **Step 3: Rename GraphqlClient methods**

In `app/services/shopify/graphql_client.rb`:
- `query` (public) -> `run_query`
- `execute_query` (private) -> `send_graphql_request`

Update internal caller in `paginate` method (calls `query` -> `run_query`).
Update internal caller in `fetch_connection` method.

**IMPORTANT:** Inside `send_graphql_request`, the line `@client.query(query: ...)` calls
ShopifyAPI's built-in method — do NOT rename that one. Only our public method changes.
Add a comment: `# @client.query is ShopifyAPI's method, not ours — don't rename it`

- [ ] **Step 4: Rename InventoryFetcher method**

In `app/services/shopify/inventory_fetcher.rb`:
- `call` -> `fetch_all_products_with_inventory`

Add comment:
```ruby
    # Fetches every product from the Shopify store along with all their
    # variants and inventory levels. Uses GraphQL pagination to handle
    # stores with thousands of products (25 products per page).
    def fetch_all_products_with_inventory
```

- [ ] **Step 5: Rename WeeklyGenerator method**

In `app/services/reports/weekly_generator.rb`:
- `generate` -> `compile_weekly_report`

- [ ] **Step 6: Rename ApplicationController method**

In `app/controllers/application_controller.rb`:
- `set_tenant` -> `scope_queries_to_current_shop`

In `app/controllers/landing_controller.rb`:
- Update `skip_before_action :set_tenant` -> `skip_before_action :scope_queries_to_current_shop`

- [ ] **Step 7: Update WebhookRegistrar caller**

In `app/services/shopify/webhook_registrar.rb`:
- `@client.query(...)` -> `@client.run_query(...)`

- [ ] **Step 8: Update InventorySyncJob callers**

In `app/jobs/inventory_sync_job.rb`:

```ruby
  def sync_inventory(shop)
    data = Shopify::InventoryFetcher.new(shop).fetch_all_products_with_inventory
    Inventory::Persister.new(shop).upsert(data)
    Inventory::Snapshotter.new(shop).create_snapshots_from_shopify_data(data)
    detect_and_alert(shop)
    shop.update!(synced_at: Time.current)
    Cache::ShopCache.new(shop).warm_inventory_stats
  end

  def detect_and_alert(shop)
    flagged = Inventory::LowStockDetector.new(shop).detect
    Notifications::AlertSender.new(shop).create_alerts_and_notify(flagged)
  end
```

- [ ] **Step 9: Update all affected spec files**

Update method calls in these test files:

| File | Change |
|------|--------|
| `spec/services/shopify/graphql_client_spec.rb` | `client.query(...)` -> `client.run_query(...)` (5 places), describe block `'#query'` -> `'#run_query'` |
| `spec/services/shopify/inventory_fetcher_spec.rb` | `fetcher.call` -> `fetcher.fetch_all_products_with_inventory` (5 places), describe block `'#call'` -> `'#fetch_all_products_with_inventory'` |
| `spec/services/inventory/snapshotter_spec.rb` | `snapshotter.snapshot(data)` -> `snapshotter.create_snapshots_from_shopify_data(data)` (4 places) |
| `spec/services/notifications/alert_sender_spec.rb` | `sender.send_low_stock_alerts(...)` -> `sender.create_alerts_and_notify(...)` (5 places) |
| `spec/services/reports/weekly_generator_spec.rb` | `generator.generate` -> `generator.compile_weekly_report` (all places) |
| `spec/jobs/inventory_sync_job_spec.rb` | Update all stubbed method names: `fetcher.call` -> `.fetch_all_products_with_inventory`, `snapshotter.snapshot` -> `.create_snapshots_from_shopify_data`, `sender.send_low_stock_alerts` -> `.create_alerts_and_notify` |
| `spec/integration/full_sync_pipeline_spec.rb` | Update: `.call` -> `.fetch_all_products_with_inventory`, `.snapshot(data)` -> `.create_snapshots_from_shopify_data(data)`, `.send_low_stock_alerts(...)` -> `.create_alerts_and_notify(...)` |
| `spec/resilience/error_handling_spec.rb` | `fetcher.call` -> `fetcher.fetch_all_products_with_inventory` (2 places) |
| `spec/services/shopify/webhook_registrar_spec.rb` | `receive(:query)` -> `receive(:run_query)` (~13 places: stubs and expectations) |
| `spec/jobs/inventory_sync_job_spec.rb` | `fetcher.call` -> `.fetch_all_products_with_inventory`, `snapshotter.snapshot` -> `.create_snapshots_from_shopify_data`, `sender.send_low_stock_alerts` -> `.create_alerts_and_notify` |
| `spec/integration/full_sync_pipeline_spec.rb` line 107 | `allow_any_instance_of(Notifications::AlertSender).to receive(:send_low_stock_alerts)` -> `receive(:create_alerts_and_notify)` |

- [ ] **Step 10: Run full test suite**

Run: `bundle exec rspec spec/`
Expected: All pass

- [ ] **Step 11: Commit**

```bash
git add app/services/ app/controllers/ app/jobs/ spec/
git commit -m "refactor: rename methods across codebase for learning clarity

Every method name now explains exactly what it does:
- snapshot -> create_snapshots_from_shopify_data
- call -> fetch_all_products_with_inventory
- query -> run_query
- send_low_stock_alerts -> create_alerts_and_notify
- set_tenant -> scope_queries_to_current_shop
- generate -> compile_weekly_report

Added learning comments explaining Ruby patterns
(insert_all, filter_map, index_by, ||= memoization)."
```

---

## Chunk 6: Delete Dead Code + Add Remaining Learning Comments

### Task 11: Delete dead code in PurchaseOrdersController

**Files:**
- Modify: `app/controllers/purchase_orders_controller.rb`

- [ ] **Step 1: Remove unused `detect_low_stock` method**

Delete lines 34-37 from `app/controllers/purchase_orders_controller.rb`:

```ruby
  # DELETE THIS:
  def detect_low_stock
    Inventory::LowStockDetector.new(current_shop).detect
  end
```

- [ ] **Step 2: Run purchase orders specs**

Run: `bundle exec rspec spec/requests/purchase_orders_html_spec.rb`
Expected: All pass

- [ ] **Step 3: Commit**

```bash
git add app/controllers/purchase_orders_controller.rb
git commit -m "chore: remove unused detect_low_stock from PurchaseOrdersController"
```

---

### Task 12: Add remaining learning comments

**Files:**
- Modify: `app/jobs/inventory_sync_job.rb`
- Modify: `app/controllers/webhooks_controller.rb`

- [ ] **Step 1: Add comments to InventorySyncJob**

```ruby
# frozen_string_literal: true

# Fetches inventory from Shopify, persists snapshots, and sends alerts.
#
# This is the main sync job — it runs daily for every shop and also
# runs immediately after a merchant installs the app.
#
class InventorySyncJob < ApplicationJob
  queue_as :default

  # retry_on tells Sidekiq to automatically retry the job if it fails
  # with specific errors, instead of crashing immediately.
  #
  # For throttle errors (Shopify rate limit): wait longer each time
  # (polynomially_longer = 1s, 4s, 9s, 16s, 25s) up to 5 attempts.
  #
  # For API errors (something broke on Shopify's side): wait 30 seconds,
  # try 3 times total, then give up and send to the dead letter queue.
  #
  retry_on Shopify::GraphqlClient::ShopifyThrottledError,
           wait: :polynomially_longer, attempts: 5
  retry_on Shopify::GraphqlClient::ShopifyApiError,
           wait: 30.seconds, attempts: 3
```

- [ ] **Step 2: Add HMAC explanation to WebhooksController**

Add comment above `verify_shopify_hmac`:

```ruby
  # HMAC VERIFICATION — how Shopify webhooks prove they're authentic:
  #
  # 1. Shopify creates a hash of the webhook body using our shared secret
  # 2. Shopify sends that hash in the X-Shopify-Hmac-SHA256 header
  # 3. We create our own hash of the body using the same secret
  # 4. If the hashes match, the webhook is genuine (not forged)
  #
  # This prevents attackers from sending fake webhooks to our endpoint.
  # secure_compare prevents timing attacks (comparing strings in constant time).
  #
```

- [ ] **Step 3: Run all specs one final time**

Run: `bundle exec rspec spec/`
Expected: All pass

- [ ] **Step 4: Final commit**

```bash
git add app/jobs/inventory_sync_job.rb app/controllers/webhooks_controller.rb
git commit -m "docs: add learning comments to InventorySyncJob and WebhooksController

Explains retry strategies (polynomially_longer vs fixed wait) and
HMAC webhook verification security pattern."
```

---

## Post-Implementation Checklist

- [ ] Run `bundle exec rubocop` — fix any style issues
- [ ] Run `bundle exec rspec spec/` — all green
- [ ] Verify no method calls reference old names — run these greps:
```bash
grep -r "\.call\b" app/services/shopify/inventory_fetcher.rb
grep -r "send_low_stock_alerts" app/ spec/ --include="*.rb"
grep -r "set_tenant" app/controllers/ --include="*.rb"
grep -r "\.generate\b" app/services/reports/ --include="*.rb"
grep -r "\.query(" app/services/shopify/ --include="*.rb" | grep -v run_query | grep -v @client
grep -r "\.snapshot(" app/services/inventory/snapshotter.rb
```
- [ ] Review diff to ensure no behavior changes were introduced
