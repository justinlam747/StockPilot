# StockPilot — Simplified HTMX Migration

**Date:** 2026-03-13
**Status:** Approved
**Scope:** Strip React, rebuild as Rails + HTMX. Minimal viable SaaS for Shopify merchants.

---

## 1. What We're Building

A standalone web app where Shopify merchants connect their store via OAuth and get agentic inventory management: stock monitoring, AI-generated purchase orders, supplier tracking. Five pages. No JS framework.

## 2. Tech Stack

| Layer | Tech |
|-------|------|
| Framework | Rails 7.2 (full mode) |
| Views | ERB + HTMX 2.0 |
| CSS | Pico CSS (classless, 10kb) + one landing.css |
| Auth | `omniauth-shopify-oauth2`, cookie sessions |
| Multi-tenancy | `acts_as_tenant` (existing) |
| DB | PostgreSQL 16 (existing) |
| Queue | Redis 7 + Sidekiq 7 (existing) |
| AI | Anthropic Claude API (existing) |
| Deploy | Fly.io or Render |

## 3. Models (8)

| Model | Status | Notes |
|-------|--------|-------|
| Shop | Keep | Tenant root, stores encrypted Shopify access token |
| Product | Keep | Synced from Shopify |
| Variant | Keep | Stock levels, velocity tracking |
| Supplier | Keep | Add `star_rating` integer column (1-5) |
| PurchaseOrder | Keep | Status: draft/sent/received/cancelled |
| PurchaseOrderLineItem | Keep | Line items per PO |
| Alert | Keep | Low stock alerts from agent runs |
| InventorySnapshot | Keep | Historical stock data for velocity calculation |

### Delete Models
- `Customer` — not used
- `WebhookEndpoint` — power-user feature, cut
- `WeeklyReport` — cut, show trends on dashboard instead

### New Migration

```ruby
class SimplifySupplierRating < ActiveRecord::Migration[7.2]
  def change
    add_column :suppliers, :star_rating, :integer, default: 0
    add_column :suppliers, :rating_notes, :text
  end
end
```

## 4. Pages (5)

### Landing (`GET /`)
Static HTML. Hero image, "$tockPilot" title, "Connect your Shopify store" button. One CSS file. No JS.

### Dashboard (`GET /dashboard`)
- KPI cards: total products, low stock count, out of stock, pending POs
- Recent alerts (dismissable via HTMX)
- Last agent run results (what was found, what was drafted)
- "Run Agent Now" button (runs synchronously, HTMX loading indicator)

### Inventory (`GET /inventory`)
- Product table with variant stock levels
- Filter tabs: All / Low Stock / Out of Stock (HTMX swap)
- Search by name/SKU (HTMX, 300ms debounce)
- Pagination (kaminari)

### Suppliers (`GET /suppliers`)
- Supplier table with name, email, lead time, star rating
- Create/edit in modal (HTMX)
- Delete with confirmation
- Inline star rating (click to update via HTMX)

### Purchase Orders (`GET /purchase_orders`)
- PO list with status badges
- PO detail with line items
- "Generate Draft" button → AI drafts PO + email text
- Merchant reviews generated email text, copies to their email client
- Mark as sent / received

## 5. Auth Flow

```
Merchant visits stockpilot.app
  → Clicks "Connect your Shopify store"
  → Enters myshopify.com domain
  → Shopify OAuth consent screen
  → Grants read_products, read_inventory, read_orders
  → Callback creates/updates Shop, sets session[:shop_id]
  → Redirect to /dashboard
```

```ruby
# Gemfile
gem "omniauth-shopify-oauth2"
gem "omniauth-rails_csrf_protection"
```

No App Bridge. No session tokens. Standard cookie auth.

## 6. Agent Pipeline

**Scheduled:** Daily at 6am per shop (sidekiq-cron)
**On-demand:** Merchant clicks "Run Agent Now" (synchronous, ~5-10s)

Pipeline per run:
1. `Inventory::LowStockDetector` — flag variants below threshold (hardcoded: 10 units)
2. `AI::InsightsGenerator` — velocity analysis, reorder recommendations
3. `AI::PoDraftGenerator` — draft POs for critical items, pick best supplier
4. Create `Alert` records for flagged items
5. Store run results on the Shop model (`last_agent_run_at`, `last_agent_results` JSON column)

No email notifications in v1. Merchant sees results on dashboard.

## 7. HTMX Patterns

Every interaction follows one of three patterns:

```html
<!-- 1. Click → swap content -->
<button hx-get="/inventory?filter=low_stock" hx-target="#product-table">
  Low Stock
</button>

<!-- 2. Form submit → swap response -->
<form hx-post="/suppliers" hx-target="#supplier-list" hx-swap="innerHTML">
  ...
</form>

<!-- 3. Click → swap with loading indicator -->
<button hx-post="/agents/run" hx-target="#agent-results" hx-indicator="#spinner">
  Run Agent Now
</button>
<span id="spinner" class="htmx-indicator">Analyzing...</span>
```

## 8. Routes

```ruby
Rails.application.routes.draw do
  root "landing#index"

  # Auth
  get "/auth/shopify/callback", to: "auth#callback"
  get "/auth/failure", to: "auth#failure"
  delete "/logout", to: "auth#destroy"

  # App
  get "/dashboard", to: "dashboard#index"
  post "/agents/run", to: "dashboard#run_agent"

  resources :inventory, only: [:index, :show]
  resources :suppliers, except: [:new, :edit]
  resources :purchase_orders do
    member do
      patch :mark_sent
      patch :mark_received
    end
    collection do
      post :generate_draft
    end
  end
  resources :alerts, only: [:index] do
    member do
      patch :dismiss
    end
  end

  # Shopify webhooks
  post "/webhooks/:topic", to: "webhooks#receive"

  # GDPR (required by Shopify)
  post "/gdpr/:action", to: "gdpr#handle"
end
```

## 9. Directory Structure

```
app/
  controllers/
    application_controller.rb    ← require_login, current_shop, set_tenant
    landing_controller.rb        ← static page, skip auth
    auth_controller.rb           ← OAuth callback, session management
    dashboard_controller.rb      ← index + run_agent
    inventory_controller.rb      ← index + show
    suppliers_controller.rb      ← CRUD + rate
    purchase_orders_controller.rb← CRUD + generate_draft + mark_sent/received
    alerts_controller.rb         ← index + dismiss
    webhooks_controller.rb       ← keep existing
    gdpr_controller.rb           ← keep existing
  models/
    shop.rb                      ← add last_agent_run_at, last_agent_results
    product.rb
    variant.rb
    supplier.rb                  ← add star_rating, rating_notes
    purchase_order.rb
    purchase_order_line_item.rb
    alert.rb
    inventory_snapshot.rb
  services/                      ← keep all existing
  jobs/                          ← keep: InventorySyncJob, DailySyncAllShopsJob,
                                    AgentInventoryCheckJob, SnapshotCleanupJob
                                    delete: WeeklyReport jobs, WebhookDeliveryJob
  views/
    layouts/
      application.html.erb       ← sidebar + main + HTMX script tag + Pico CSS
      landing.html.erb           ← minimal, no sidebar
    shared/
      _sidebar.html.erb
      _flash.html.erb
      _pagination.html.erb
      _modal.html.erb
    landing/
      index.html.erb
    dashboard/
      index.html.erb
      _kpi_cards.html.erb
      _alerts.html.erb
      _agent_results.html.erb
    inventory/
      index.html.erb
      show.html.erb
      _table.html.erb
    suppliers/
      index.html.erb
      show.html.erb
      _list.html.erb
      _form.html.erb
    purchase_orders/
      index.html.erb
      show.html.erb
      _list.html.erb
      _form.html.erb
      _draft_preview.html.erb
    alerts/
      _list.html.erb
      _row.html.erb
public/
  images/                        ← hero-bg.jpg, shopify-bag.png etc.
```

## 10. What Gets Deleted

**Entire directories:**
- `frontend/` (all React, TypeScript, components, pages, hooks, tests, styles)
- `e2e/`
- `test/` (Vite playground)
- `playwright-report/`, `test-results/`

**Files:**
- `package.json`, `package-lock.json`
- `vite.config.ts`, `vite.preview.config.ts`, `vitest.config.ts`
- `tsconfig.json`, `playwright.config.ts`
- `index.html`

**Gems to remove:**
- `vite_ruby`
- `shopify_app` (replaced by omniauth)

**Models/migrations to delete:**
- `Customer` model + migration
- `WebhookEndpoint` model + migration
- `WeeklyReport` model + migration

**Jobs to delete:**
- `WeeklyReportJob`, `WeeklyReportAllShopsJob`
- `WebhookDeliveryJob`

**Services to keep all** — they're the core logic.

## 11. New Migration: Agent Results on Shop

```ruby
class AddAgentResultsToShops < ActiveRecord::Migration[7.2]
  def change
    add_column :shops, :last_agent_run_at, :datetime
    add_column :shops, :last_agent_results, :jsonb, default: {}
  end
end
```

## 12. CSS Strategy

**Pico CSS** (classless) as the base. It styles semantic HTML automatically:
- `<table>` → styled table
- `<input>` → styled input
- `<button>` → styled button
- `<dialog>` → styled modal
- `<nav>` → styled nav

One additional file `landing.css` for the landing page hero + dotted grid.

One additional file `overrides.css` for minor tweaks (sidebar width, KPI card layout, alert colors).

**No CSS build step.** Files served directly via Rails asset pipeline (Propshaft).

## 13. Security Hardening

### 13a. Rack::Attack Rate Limiting

```ruby
# config/initializers/rack_attack.rb
class Rack::Attack
  # Throttle all requests by IP
  throttle("req/ip", limit: 60, period: 1.minute) do |req|
    req.ip unless req.path.start_with?("/assets")
  end

  # Strict limit on agent runs (expensive — AI calls)
  throttle("agents/ip", limit: 5, period: 1.minute) do |req|
    req.ip if req.path == "/agents/run" && req.post?
  end

  # Strict limit on PO draft generation (expensive — AI calls)
  throttle("po-draft/ip", limit: 5, period: 1.minute) do |req|
    req.ip if req.path == "/purchase_orders/generate_draft" && req.post?
  end

  # Block suspicious auth attempts
  throttle("auth/ip", limit: 10, period: 5.minutes) do |req|
    req.ip if req.path.start_with?("/auth")
  end

  # Webhook endpoint (Shopify retries, be generous)
  throttle("webhooks/ip", limit: 100, period: 1.minute) do |req|
    req.ip if req.path.start_with?("/webhooks")
  end

  # Custom response for throttled requests
  self.throttled_responder = lambda do |matched, _period, _limit, _count|
    now = Time.current
    html = "<html><body><h1>429 Too Many Requests</h1><p>Retry later.</p></body></html>"
    [429, { "Content-Type" => "text/html", "Retry-After" => "60" }, [html]]
  end
end
```

**RSpec test:**
```ruby
# spec/requests/rate_limiting_spec.rb
RSpec.describe "Rate limiting", type: :request do
  it "throttles excessive requests" do
    70.times { get "/dashboard" }
    expect(response.status).to eq(429)
  end

  it "throttles agent runs" do
    6.times { post "/agents/run" }
    expect(response.status).to eq(429)
  end
end
```

### 13b. Security Headers

```ruby
# config/initializers/security_headers.rb
Rails.application.config.action_dispatch.default_headers = {
  "Strict-Transport-Security" => "max-age=31536000; includeSubDomains",
  "X-Content-Type-Options" => "nosniff",
  "X-Frame-Options" => "DENY",
  "Referrer-Policy" => "strict-origin-when-cross-origin",
  "Permissions-Policy" => "camera=(), microphone=(), geolocation=()",
  "Content-Security-Policy" => [
    "default-src 'self'",
    "script-src 'self' https://unpkg.com",       # HTMX from CDN
    "style-src 'self' https://unpkg.com 'unsafe-inline'", # Pico CSS
    "img-src 'self' data:",
    "font-src 'self'",
    "connect-src 'self'",
    "frame-ancestors 'none'",
    "base-uri 'self'",
    "form-action 'self' https://*.myshopify.com", # OAuth redirect
  ].join("; ")
}
```

**RSpec test:**
```ruby
# spec/requests/security_headers_spec.rb
RSpec.describe "Security headers", type: :request do
  before { get "/dashboard" } # any authenticated page

  it "sets Strict-Transport-Security" do
    expect(response.headers["Strict-Transport-Security"]).to include("max-age=31536000")
  end

  it "sets X-Content-Type-Options" do
    expect(response.headers["X-Content-Type-Options"]).to eq("nosniff")
  end

  it "sets X-Frame-Options to DENY" do
    expect(response.headers["X-Frame-Options"]).to eq("DENY")
  end

  it "sets Content-Security-Policy" do
    csp = response.headers["Content-Security-Policy"]
    expect(csp).to include("default-src 'self'")
    expect(csp).to include("frame-ancestors 'none'")
  end

  it "sets Referrer-Policy" do
    expect(response.headers["Referrer-Policy"]).to eq("strict-origin-when-cross-origin")
  end

  it "sets Permissions-Policy" do
    expect(response.headers["Permissions-Policy"]).to include("camera=()")
  end
end
```

### 13c. Brakeman Static Analysis

Add to CI pipeline and pre-commit:

```bash
# Run brakeman
bundle exec brakeman --no-pager -q

# In CI (GitHub Actions)
- name: Security scan
  run: bundle exec brakeman --no-pager -q --ensure-latest
```

```ruby
# Gemfile (development/test group)
gem "brakeman", require: false
```

**RSpec wrapper (runs brakeman as part of test suite):**
```ruby
# spec/security/brakeman_spec.rb
RSpec.describe "Brakeman security scan" do
  it "finds no warnings" do
    result = `bundle exec brakeman --no-pager -q --format json`
    report = JSON.parse(result)
    warnings = report["warnings"]
    expect(warnings).to be_empty, "Brakeman found #{warnings.size} warnings:\n#{warnings.map { |w| "  - #{w['warning_type']}: #{w['message']} (#{w['file']}:#{w['line']})" }.join("\n")}"
  end
end
```

### 13d. GDPR Data Processing (Real Implementation)

Replace the stub endpoints with actual data handling:

```ruby
# app/controllers/gdpr_controller.rb
class GdprController < ActionController::Base
  skip_before_action :verify_authenticity_token
  before_action :verify_shopify_hmac

  # POST /gdpr/customers_data_request
  def customers_data_request
    shop = Shop.find_by(shopify_domain: params[:shop_domain])
    return head :not_found unless shop

    # Export all stored customer-related data
    # (We only store inventory/supplier data — no direct customer PII)
    # Respond with confirmation that request is received
    GdprCustomerDataJob.perform_later(shop.id, params[:customer]&.dig(:id))
    head :ok
  end

  # POST /gdpr/customers_redact
  def customers_redact
    shop = Shop.find_by(shopify_domain: params[:shop_domain])
    return head :not_found unless shop

    # Delete any stored customer data for this customer
    GdprCustomerRedactJob.perform_later(shop.id, params[:customer]&.dig(:id))
    head :ok
  end

  # POST /gdpr/shop_redact
  def shop_redact
    shop = Shop.find_by(shopify_domain: params[:shop_domain])
    return head :not_found unless shop

    # Delete ALL data for this shop — they've uninstalled
    GdprShopRedactJob.perform_later(shop.id)
    head :ok
  end

  private

  def verify_shopify_hmac
    body = request.body.read
    hmac = request.headers["HTTP_X_SHOPIFY_HMAC_SHA256"]
    return head :unauthorized unless hmac.present?
    digest = OpenSSL::HMAC.digest("sha256", ENV.fetch("SHOPIFY_API_SECRET"), body)
    expected = Base64.strict_encode64(digest)
    head :unauthorized unless ActiveSupport::SecurityUtils.secure_compare(expected, hmac)
  end
end
```

```ruby
# app/jobs/gdpr_shop_redact_job.rb
class GdprShopRedactJob < ApplicationJob
  queue_as :default

  def perform(shop_id)
    shop = Shop.find_by(id: shop_id)
    return unless shop

    # Delete all tenant-scoped data in order (respecting foreign keys)
    ActsAsTenant.with_tenant(shop) do
      PurchaseOrderLineItem.delete_all
      PurchaseOrder.delete_all
      Alert.delete_all
      InventorySnapshot.delete_all
      Variant.delete_all
      Product.delete_all
      Supplier.delete_all
    end

    shop.destroy!
    Rails.logger.info("[GDPR] Shop #{shop_id} fully redacted")
  end
end
```

**RSpec tests:**
```ruby
# spec/requests/gdpr_spec.rb
RSpec.describe "GDPR endpoints", type: :request do
  let(:shop) { create(:shop) }
  let(:secret) { ENV.fetch("SHOPIFY_API_SECRET", "test-secret") }

  def shopify_hmac(body)
    digest = OpenSSL::HMAC.digest("sha256", secret, body)
    Base64.strict_encode64(digest)
  end

  describe "POST /gdpr/shop_redact" do
    it "queues shop data deletion" do
      body = { shop_domain: shop.shopify_domain }.to_json
      headers = {
        "HTTP_X_SHOPIFY_HMAC_SHA256" => shopify_hmac(body),
        "CONTENT_TYPE" => "application/json"
      }
      expect {
        post "/gdpr/shop_redact", params: body, headers: headers
      }.to have_enqueued_job(GdprShopRedactJob).with(shop.id)
      expect(response).to have_http_status(:ok)
    end

    it "rejects requests without valid HMAC" do
      body = { shop_domain: shop.shopify_domain }.to_json
      headers = {
        "HTTP_X_SHOPIFY_HMAC_SHA256" => "invalid",
        "CONTENT_TYPE" => "application/json"
      }
      post "/gdpr/shop_redact", params: body, headers: headers
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "POST /gdpr/customers_redact" do
    it "queues customer data deletion" do
      body = { shop_domain: shop.shopify_domain, customer: { id: 123 } }.to_json
      headers = {
        "HTTP_X_SHOPIFY_HMAC_SHA256" => shopify_hmac(body),
        "CONTENT_TYPE" => "application/json"
      }
      expect {
        post "/gdpr/customers_redact", params: body, headers: headers
      }.to have_enqueued_job(GdprCustomerRedactJob).with(shop.id, 123)
      expect(response).to have_http_status(:ok)
    end
  end
end

# spec/jobs/gdpr_shop_redact_job_spec.rb
RSpec.describe GdprShopRedactJob do
  let(:shop) { create(:shop) }

  before do
    ActsAsTenant.with_tenant(shop) do
      supplier = create(:supplier)
      product = create(:product)
      variant = create(:variant, product: product)
      create(:alert, variant: variant)
      create(:inventory_snapshot, variant: variant)
      po = create(:purchase_order, supplier: supplier)
      create(:purchase_order_line_item, purchase_order: po, variant: variant)
    end
  end

  it "deletes all shop data and the shop itself" do
    expect { described_class.new.perform(shop.id) }
      .to change(Shop, :count).by(-1)
      .and change(Product, :count).by(-1)
      .and change(Variant, :count).by(-1)
      .and change(Supplier, :count).by(-1)
      .and change(Alert, :count).by(-1)
      .and change(PurchaseOrder, :count).by(-1)
  end
end
```

### 13e. Audit Logging

Simple append-only audit log table for security events:

```ruby
# Migration
class CreateAuditLogs < ActiveRecord::Migration[7.2]
  def change
    create_table :audit_logs do |t|
      t.references :shop, foreign_key: true
      t.string :action, null: false         # login, logout, agent_run, po_created, gdpr_request, rate_limited, etc.
      t.string :ip_address
      t.string :user_agent
      t.string :request_id
      t.jsonb :metadata, default: {}        # action-specific details
      t.datetime :created_at, null: false   # no updated_at — append only
    end

    add_index :audit_logs, :action
    add_index :audit_logs, :created_at
    add_index :audit_logs, [:shop_id, :created_at]
  end
end
```

```ruby
# app/models/audit_log.rb
class AuditLog < ApplicationRecord
  belongs_to :shop, optional: true  # some events (failed login) have no shop

  # Append-only: no updates or deletes
  def readonly?
    persisted?
  end

  def self.record(action:, shop: nil, request: nil, metadata: {})
    create!(
      action: action,
      shop: shop,
      ip_address: request&.remote_ip,
      user_agent: request&.user_agent&.truncate(500),
      request_id: request&.request_id,
      metadata: metadata
    )
  end
end
```

```ruby
# Usage in controllers:
class AuthController < ApplicationController
  skip_before_action :require_login

  def callback
    shop = Shop.find_or_create_from_auth(auth_hash)
    session[:shop_id] = shop.id
    reset_session_and_login(shop)
    AuditLog.record(action: "login", shop: shop, request: request)
    redirect_to dashboard_path
  end

  def destroy
    AuditLog.record(action: "logout", shop: current_shop, request: request)
    reset_session
    redirect_to root_path
  end
end

class DashboardController < ApplicationController
  def run_agent
    AuditLog.record(action: "agent_run", shop: current_shop, request: request)
    # ... run agent
  end
end

class GdprController < ActionController::Base
  def shop_redact
    AuditLog.record(action: "gdpr_shop_redact", request: request,
                    metadata: { shop_domain: params[:shop_domain] })
    # ...
  end
end
```

**Events to log:**
| Event | When |
|-------|------|
| `login` | OAuth callback success |
| `login_failed` | OAuth failure |
| `logout` | Session destroy |
| `agent_run` | Manual agent trigger |
| `po_created` | Purchase order created |
| `po_draft_generated` | AI generated a PO draft |
| `supplier_created` | New supplier added |
| `supplier_deleted` | Supplier removed |
| `gdpr_customer_data_request` | Shopify GDPR webhook |
| `gdpr_customer_redact` | Shopify GDPR webhook |
| `gdpr_shop_redact` | Shopify GDPR webhook |
| `rate_limited` | Rack::Attack throttle hit |

**RSpec tests:**
```ruby
# spec/models/audit_log_spec.rb
RSpec.describe AuditLog do
  let(:shop) { create(:shop) }

  it "records an event" do
    log = AuditLog.record(action: "login", shop: shop, metadata: { source: "oauth" })
    expect(log).to be_persisted
    expect(log.action).to eq("login")
    expect(log.shop).to eq(shop)
    expect(log.metadata["source"]).to eq("oauth")
  end

  it "is readonly once persisted" do
    log = AuditLog.record(action: "test", shop: shop)
    expect { log.update!(action: "changed") }.to raise_error(ActiveRecord::ReadOnlyRecord)
  end

  it "allows nil shop for unauthenticated events" do
    log = AuditLog.record(action: "login_failed", metadata: { reason: "invalid_shop" })
    expect(log).to be_persisted
    expect(log.shop).to be_nil
  end
end

# spec/requests/audit_logging_spec.rb
RSpec.describe "Audit logging", type: :request do
  let(:shop) { create(:shop) }

  before { login_as(shop) }

  it "logs agent runs" do
    expect {
      post "/agents/run"
    }.to change(AuditLog.where(action: "agent_run"), :count).by(1)
  end

  it "logs PO creation" do
    expect {
      post "/purchase_orders", params: { purchase_order: valid_po_params }
    }.to change(AuditLog.where(action: "po_created"), :count).by(1)
  end
end
```

### 13f. Webhook HMAC Verification

```ruby
# app/controllers/webhooks_controller.rb
class WebhooksController < ActionController::Base
  skip_before_action :verify_authenticity_token
  before_action :verify_shopify_hmac

  def receive
    topic = params[:topic]
    # ... handle webhook
    AuditLog.record(action: "webhook_received", metadata: { topic: topic })
    head :ok
  end

  private

  def verify_shopify_hmac
    body = request.body.read
    hmac = request.headers["HTTP_X_SHOPIFY_HMAC_SHA256"]
    return head :unauthorized unless hmac.present?
    digest = OpenSSL::HMAC.digest("sha256", ENV.fetch("SHOPIFY_API_SECRET"), body)
    expected = Base64.strict_encode64(digest)
    unless ActiveSupport::SecurityUtils.secure_compare(expected, hmac)
      AuditLog.record(action: "webhook_hmac_failed", request: request)
      head :unauthorized
    end
  end
end
```

**RSpec test:**
```ruby
# spec/requests/webhooks_spec.rb
RSpec.describe "Webhook HMAC verification", type: :request do
  let(:secret) { ENV.fetch("SHOPIFY_API_SECRET", "test-secret") }

  it "accepts valid HMAC" do
    body = { topic: "products/update" }.to_json
    digest = OpenSSL::HMAC.digest("sha256", secret, body)
    hmac = Base64.strict_encode64(digest)
    post "/webhooks/products_update", params: body,
      headers: { "HTTP_X_SHOPIFY_HMAC_SHA256" => hmac, "CONTENT_TYPE" => "application/json" }
    expect(response).to have_http_status(:ok)
  end

  it "rejects invalid HMAC" do
    post "/webhooks/products_update", params: "{}",
      headers: { "HTTP_X_SHOPIFY_HMAC_SHA256" => "bad", "CONTENT_TYPE" => "application/json" }
    expect(response).to have_http_status(:unauthorized)
  end

  it "rejects missing HMAC" do
    post "/webhooks/products_update", params: "{}", headers: { "CONTENT_TYPE" => "application/json" }
    expect(response).to have_http_status(:unauthorized)
  end
end
```

### 13g. Session Security

```ruby
# config/initializers/session_store.rb
Rails.application.config.session_store :cookie_store,
  key: "_stockpilot_session",
  expire_after: 24.hours,
  secure: Rails.env.production?,
  httponly: true,
  same_site: :lax
```

```ruby
# In auth callback — prevent session fixation
def callback
  reset_session  # destroy old session before setting new one
  shop = Shop.find_or_create_from_auth(auth_hash)
  session[:shop_id] = shop.id
  # ...
end
```

## 14. Testing Summary

### Test files for security:

| File | Tests |
|------|-------|
| `spec/requests/rate_limiting_spec.rb` | Rack::Attack throttles on all endpoints |
| `spec/requests/security_headers_spec.rb` | All 6 security headers present and correct |
| `spec/security/brakeman_spec.rb` | Zero brakeman warnings |
| `spec/requests/gdpr_spec.rb` | All 3 GDPR endpoints verify HMAC and queue jobs |
| `spec/jobs/gdpr_shop_redact_job_spec.rb` | Full shop data deletion |
| `spec/models/audit_log_spec.rb` | Append-only, records events correctly |
| `spec/requests/audit_logging_spec.rb` | Key actions produce audit log entries |
| `spec/requests/webhooks_spec.rb` | HMAC verification accepts valid, rejects invalid/missing |
| `spec/requests/auth_spec.rb` | Session fixation prevention, login/logout flow |

### Other tests (keep existing + add):

- **Keep:** All existing model, service, job specs
- **Delete:** All Vitest, Testing Library, Playwright frontend tests
- **Add:** RSpec request specs for all new controllers (dashboard, inventory, suppliers, purchase_orders, alerts)

## 15. Deploy

Fly.io or Render. One `fly.toml` or `render.yaml`:
- Web: `rails server`
- Worker: `sidekiq`
- DB: Managed Postgres
- Cache: Managed Redis
- Env vars: SHOPIFY_API_KEY, SHOPIFY_API_SECRET, ANTHROPIC_API_KEY, DATABASE_URL, REDIS_URL

---

## 16. What's Deferred to v2

- Email sending (SendGrid, PO delivery)
- Supplier rating tracking (response time, shipping time, quality auto-calculation)
- Settings page (thresholds, timezone, notification preferences)
- Weekly email reports
- Customer DNA profiles
- Webhook management
- Real-time agent status polling (async with Turbo Streams or polling)
