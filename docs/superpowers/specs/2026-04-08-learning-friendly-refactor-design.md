# Learning-Friendly Codebase Refactor

**Goal:** Make every function in the codebase tell a clear story. Rename vague methods, break long methods into named steps, merge duplicate code paths, remove dead code, and add "why/how Ruby works" comments where useful.

**Audience:** A developer learning Ruby through this codebase. Every file should read like a tutorial.

**Principles:**
- One function = one job, with a name that explains what it does
- No clever abstractions — prefer obvious over elegant
- Comments explain "why" and Ruby idioms, not "what" (the name does that)
- Duplicate code gets merged into one clear version
- Dead code gets deleted — less to read = easier to learn

---

## Refactor 1: Inventory::Persister — Merge Duplicate Paths

**File:** `app/services/inventory/persister.rb` (88 LOC)

**Problem:** Two nearly identical code paths exist — one for webhooks (`upsert_single_product`), one for GraphQL batch (`upsert`). They duplicate product attribute assignment and variant saving with slightly different field names. A learner reads both and wonders "which one matters?"

**What changes:**

1. **Add `normalize_product_data(raw_data, source:)`** — takes raw webhook OR GraphQL hash, returns a uniform hash with consistent keys. This teaches Ruby hash transformation.

2. **Add `normalize_variant_data(raw_data, source:)`** — same pattern for variants.

3. **Replace `assign_product_attrs` + `assign_graphql_product_attrs`** with one `save_product(product, normalized_data)`.

4. **Replace `upsert_webhook_variants` + `upsert_graphql_variants`** with one `save_variants(product, normalized_variants)`.

5. Both `upsert` and `upsert_single_product` call normalize then save — one path to understand.

**Before (confusing — two paths):**
```ruby
def upsert_single_product(shopify_data)
  product = find_or_init_product(shopify_data['id'].to_s)
  assign_product_attrs(product, shopify_data)        # path A
  product.save!
  upsert_webhook_variants(product, ...)              # path A
end

def upsert_product_from_graphql(node)
  product = find_or_init_product(node['legacyResourceId'].to_s)
  assign_graphql_product_attrs(product, node)        # path B
  product.save!
  upsert_graphql_variants(product, ...)              # path B
end
```

**After (one path):**
```ruby
def upsert_single_product(raw_data, source:)
  normalized = normalize_product_data(raw_data, source: source)
  product = find_or_initialize_product(normalized[:shopify_id])
  save_product(product, normalized)
  save_variants(product, normalized[:variants])
  product
end
```

**Callers that must be updated for the new `source:` keyword:**
- `app/controllers/webhooks_controller.rb` line 53 — add `source: :webhook`
- `app/jobs/inventory_sync_job.rb` — the `upsert` method (batch path) passes `source: :graphql` internally
- `spec/services/inventory/persister_spec.rb` — all `upsert_single_product` calls need `source:` keyword
- `spec/concurrency/race_conditions_spec.rb` lines 202, 206 — add `source:` keyword

---

## Refactor 2: InventoryController — Slim Down, Name Clearly

**File:** `app/controllers/inventory_controller.rb` (128 LOC)

**Problem:** Complex SQL (DISTINCT ON subqueries), filtering, sorting, and chart data building all live in the controller. A learner has to understand SQL joins, Arel, and ActiveRecord scopes just to follow the inventory page.

**What changes:**

1. **Move stock-level scopes to the Product model** — `scope :with_low_stock`, `scope :out_of_stock_only`, `scope :search_by_title_or_sku`. Models are where Rails developers look for query logic.

2. **Move "latest snapshot per variant" query to InventorySnapshot model** — `InventorySnapshot.latest_for_variants(variant_ids, shop_id:)`. This is reused in 3 places across the codebase (controller, LowStockDetector, cache). One definition, three callers.

3. **Move chart data building to a simple method on InventorySnapshot** — `InventorySnapshot.daily_totals(variant_ids, days:)`.

4. **Controller becomes ~50 lines** — just HTTP concerns: read params, call model scopes, paginate, render.

5. **Rename methods for clarity:**
   - `build_product_scope` -> `find_filtered_products`
   - `preload_current_stock` -> `attach_current_stock_to_variants`
   - `load_snapshot_history` -> `load_chart_data_for_product`

---

## Refactor 3: DashboardController — Extract Stats Loading

**File:** `app/controllers/dashboard_controller.rb` (73 LOC)

**Problem:** `load_dashboard_stats` sets 12 instance variables with scattered queries. `compute_trends` has hardcoded values (24 hours, threshold of 10). Hard to follow.

**What changes:**

1. **Keep instance variables** (the dashboard view uses them directly in 30+ places — switching to a hash would be churn for no learning benefit). Clean up the controller methods instead.

2. **Use `current_shop.low_stock_threshold`** instead of hardcoded `10` in `previous_counts`. The raw SQL `'available > 0 AND available <= 10'` becomes `where('available > 0 AND available <= ?', current_shop.low_stock_threshold)`.

3. **Rename `previous_counts`** to `counts_from_yesterday` — says exactly what it computes.

4. **Add comments explaining the trend logic** — "we compare today's counts to yesterday's to show up/down arrows."

---

## Refactor 4: Cache::ShopCache — Split Fast Stats from Full Detection

**File:** `app/services/cache/shop_cache.rb` (113 LOC)

**Problem:** `build_inventory_stats` calls `Inventory::LowStockDetector.new(@shop).detect` which runs an expensive SQL query with DISTINCT ON + joins. This runs every time the 2-minute cache expires, even if the dashboard just needs counts.

**What changes:**

1. **Add `InventorySnapshot.count_by_stock_status(shop)`** — a lightweight COUNT query on the model, no full variant loading. Used for dashboard stats.

2. **`build_inventory_stats` uses the lightweight count** instead of loading all flagged variants.

3. **`LowStockDetector.detect` stays as-is** — it's still needed when creating alerts (needs full variant objects). But it's no longer called just to count things.

4. **Fix `WeeklyGenerator` calling `LowStockDetector.detect` twice** — once in `low_sku_count` (line 78) and once in `reorder_suggestions` (line 82). Memoize the result so the expensive query only runs once per report generation.

5. **Add comments explaining the caching strategy** — TTLs, write-through vs cache-aside, why inventory has a short TTL.

---

## Refactor 5: Shared "Latest Snapshot" Query — One Definition

**Problem:** The "get the most recent snapshot per variant" SQL pattern (using DISTINCT ON) is copy-pasted in 3 places:
- `InventoryController#latest_snapshot_sql` (line 55)
- `InventoryController#latest_stock_for` (line 121)
- `Inventory::LowStockDetector#latest_snapshots_sql` (line 27)

Note: `WeeklyGenerator#snapshot_map` (line 32) also uses DISTINCT ON but with a variable sort direction (ASC for start-of-week, DESC for end-of-week). This is a different enough pattern that it stays separate.

**What changes:**

1. **Add one class method to InventorySnapshot** that returns an ActiveRecord **relation** (not materialized records). This lets callers chain `.to_sql` (for joins) or `.index_by` (for hash lookup):
   ```ruby
   # Returns a relation of the most recent snapshot for each variant.
   # Uses PostgreSQL DISTINCT ON to pick the latest row per variant_id.
   #
   # Returns a relation so callers can use it flexibly:
   #   .to_sql   -> for use as a SQL subquery in joins
   #   .index_by -> for building a lookup hash
   #   .where()  -> for further filtering
   def self.latest_per_variant(shop_id:, variant_ids: nil, columns: %w[variant_id available])
   ```

2. **All 3 callers (not WeeklyGenerator) use this one method** — InventoryController, LowStockDetector, and ShopCache.

3. **Comment explains DISTINCT ON** — "PostgreSQL-specific: picks the first row per group after ORDER BY. Here it gets the newest snapshot per variant."

---

## Refactor 6: PurchaseOrdersController — Remove Dead Code

**File:** `app/controllers/purchase_orders_controller.rb` (38 LOC)

**Problem:** `detect_low_stock` (line 35-37) is defined but never called anywhere.

**What changes:** Delete it. Less code to read.

---

## Refactor 7: Rename Vague Methods Across Codebase

These methods work fine but their names don't explain what they do:

| File | Current Name | New Name | Why |
|------|-------------|----------|-----|
| `Snapshotter` | `snapshot(products_data)` | `create_snapshots_from_shopify_data(data)` | Says what it creates and from what |
| `Snapshotter` | `build_snapshot_rows(products)` | `build_snapshot_rows_for_all_products(products)` | Clear it iterates all products; keeps `build_` prefix consistent with `build_one_snapshot_row` |
| `Snapshotter` | `build_variant_row(vnode)` | `build_one_snapshot_row(variant_node)` | Clear it's one row |
| `AlertSender` | `send_low_stock_alerts(flagged_variants)` | `create_alerts_and_notify(flagged_variants)` | Says it creates records AND sends email |
| `AlertSender` | `filter_new_alerts(flagged_variants)` | `remove_already_alerted_today(flagged_variants)` | Says exactly what the filter does |
| `GraphqlClient` | `query(graphql_query, variables:)` | `run_query(graphql_query, variables:)` | Avoids confusion with "query" the noun; `execute` would collide with existing private `execute_query` |
| `GraphqlClient` | `execute_query(graphql_query, variables)` (private) | `send_graphql_request(graphql_query, variables)` (private) | Avoids confusion with renamed public `run_query` |
| `InventoryFetcher` | `call` | `fetch_all_products_with_inventory` | Says what it fetches |
| `WeeklyGenerator` | `generate` | `compile_weekly_report` | Says what it generates |
| `ApplicationController` | `set_tenant` | `scope_queries_to_current_shop` | Explains what tenant scoping actually does |

**Callers that must be updated for the `set_tenant` rename:**
- `app/controllers/landing_controller.rb` — `skip_before_action :set_tenant` becomes `skip_before_action :scope_queries_to_current_shop`

**Callers that must be updated for the `run_query` rename:**
- `app/services/shopify/graphql_client.rb` — internal `paginate` method calls `query(...)` on line 47
- `app/services/shopify/webhook_registrar.rb` — calls `@client.query(...)` on line 37
- `spec/services/shopify/graphql_client_spec.rb` — calls `.query(...)` ~5 times
- `spec/services/shopify/inventory_fetcher_spec.rb` — may stub `query`

**Callers that must be updated for the `fetch_all_products_with_inventory` rename:**
- `app/jobs/inventory_sync_job.rb` line 20 — calls `fetcher.call`
- `spec/services/shopify/inventory_fetcher_spec.rb` — calls `.call`
- `spec/integration/full_sync_pipeline_spec.rb` — stubs `.call`
- `spec/resilience/error_handling_spec.rb` — calls `fetcher.call`

---

## Refactor 8: Add Learning Comments

Add "why/how" comments in these specific spots:

1. **`acts_as_tenant :shop`** on every model — explain what multi-tenancy means and why every query gets auto-scoped
2. **`encrypts :access_token`** in Shop — explain Rails 7 encryption at rest
3. **`DISTINCT ON`** in InventorySnapshot — explain the PostgreSQL pattern
4. **`filter_map`** usages — explain it's like `.map` but skips `nil` results
5. **`find_or_initialize_by`** in Persister — explain it finds an existing record or builds a new one in memory
6. **`insert_all`** in Snapshotter — explain bulk insert vs individual `.save!` calls
7. **`index_by`** usages — explain it turns an array into a hash keyed by the block
8. **Retry strategies** in InventorySyncJob — explain `polynomially_longer` and why different errors get different strategies
9. **`scope`** declarations — explain what a scope is (named query shortcut) on the first model that uses one
10. **HMAC verification** in WebhooksController — explain the security pattern

---

## What We Do NOT Touch

These are already clean and learning-friendly:

- **Models** (Shop, Alert, Product, Variant, etc.) — small, clear, well-validated
- **Routes** — RESTful, standard Rails conventions
- **Jobs** (except rename opportunity) — well-structured, good retry logic
- **GdprController / GDPR jobs** — compliance code, works correctly
- **WebhooksController** — clean dispatch pattern, good HMAC verification (note: will need a small caller update in Refactor 1 to pass `source: :webhook` to Persister)
- **SuppliersController** — already clean CRUD
- **SettingsController** — already minimal
- **Config/initializers** — already documented

---

## Files Changed Summary

| File | Type of Change |
|------|---------------|
| `app/services/inventory/persister.rb` | Merge duplicate paths, rename methods |
| `app/controllers/inventory_controller.rb` | Move queries to models, slim to ~50 LOC |
| `app/controllers/dashboard_controller.rb` | Replace instance vars with hash, fix hardcoded values |
| `app/services/cache/shop_cache.rb` | Use lightweight count query, add caching comments |
| `app/models/inventory_snapshot.rb` | Add `latest_per_variant` and `daily_totals` class methods |
| `app/models/product.rb` | Add stock-level filter scopes |
| `app/services/inventory/low_stock_detector.rb` | Use shared `latest_per_variant` |
| `app/controllers/purchase_orders_controller.rb` | Delete dead `detect_low_stock` |
| `app/services/inventory/snapshotter.rb` | Rename methods for clarity |
| `app/services/notifications/alert_sender.rb` | Rename methods for clarity |
| `app/services/shopify/graphql_client.rb` | Rename `query` -> `run_query`, `execute_query` -> `send_graphql_request` |
| `app/services/shopify/inventory_fetcher.rb` | Rename `call` -> `fetch_all_products_with_inventory` |
| `app/services/reports/weekly_generator.rb` | Rename + use shared snapshot query |
| `app/controllers/application_controller.rb` | Rename `set_tenant` |
| Multiple models | Add learning comments for Ruby/Rails patterns |
| Multiple files | Update callers of renamed methods |

---

## Test Impact

Behavior stays the same — no new features, no deleted features. But method renames mean test files must be updated to call the new names. **Each PR updates its own tests** so every PR stays green independently.

**Test files that need updates (by PR):**

| PR | Test Files Affected |
|----|-------------------|
| PR 1 | `spec/services/inventory/low_stock_detector_spec.rb` (uses shared snapshot method now) |
| PR 2 | `spec/services/inventory/persister_spec.rb`, `spec/concurrency/race_conditions_spec.rb` (new `source:` keyword) |
| PR 3 | `spec/requests/inventory_spec.rb` (if scopes change query interface) |
| PR 4 | `spec/services/cache/shop_cache_spec.rb`, `spec/services/reports/weekly_generator_spec.rb` (memoized detect) |
| PR 5 | `spec/services/shopify/graphql_client_spec.rb` (~5 calls), `spec/services/shopify/inventory_fetcher_spec.rb` (~5 calls), `spec/services/reports/weekly_generator_spec.rb` (~14 calls), `spec/services/notifications/alert_sender_spec.rb` (~5 calls), `spec/services/inventory/snapshotter_spec.rb` (~4 calls), `spec/integration/full_sync_pipeline_spec.rb`, `spec/resilience/error_handling_spec.rb`, `spec/jobs/inventory_sync_job_spec.rb` |

---

## PR Stack (following CLAUDE.md sizing rules)

Each PR includes its own test updates so CI stays green at every step.

1. **PR 1: Add shared `InventorySnapshot.latest_per_variant`** — model method + learning comments + update detector spec (~150 LOC)
2. **PR 2: Refactor Persister — merge duplicate paths** + update persister/concurrency/webhook specs (~200 LOC)
3. **PR 3: Slim InventoryController — move queries to models** + update request specs (~250 LOC)
4. **PR 4: Fix DashboardController + ShopCache + WeeklyGenerator memoization** + update cache/report specs (~200 LOC)
5. **PR 5: Rename methods + add learning comments across codebase** + update all affected specs (~300 LOC)
6. **PR 6: Delete dead code** (~50 LOC)
