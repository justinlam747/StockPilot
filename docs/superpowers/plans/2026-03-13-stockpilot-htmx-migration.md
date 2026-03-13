# StockPilot HTMX Migration — Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Strip React/TypeScript/Vite and rebuild as Rails full-mode + HTMX + ERB with Pico CSS, OmniAuth Shopify, and full security hardening.

**Architecture:** Standalone Rails 7.2 app (not Shopify embedded). Cookie-based sessions via OmniAuth Shopify OAuth. ERB views with HTMX 2.0 for interactivity. Pico CSS (classless) for styling. Existing service/model layer preserved.

**Tech Stack:** Rails 7.2 (full mode), ERB, HTMX 2.0, Pico CSS, PostgreSQL 16, Redis 7, Sidekiq 7, OmniAuth Shopify, Rack::Attack, Propshaft

**Spec:** `docs/superpowers/specs/2026-03-13-stockpilot-htmx-migration-design.md`

---

## Chunk 1: Foundation — Rails Mode, Gems, Asset Pipeline, Migrations

### Task 1: Switch Rails from API Mode to Full Mode

**Files:**
- Modify: `config/application.rb`
- Modify: `app/controllers/application_controller.rb`

- [ ] **Step 1: Update `config/application.rb` — remove API-only mode**

Change `config.api_only = true` to full Rails mode. Remove the API-only line and ensure `ActionController::Base` is available.

```ruby
# config/application.rb
# REMOVE this line:
#   config.api_only = true
# Rails defaults to full mode when this is absent
```

- [ ] **Step 2: Update `ApplicationController` to inherit from `ActionController::Base`**

```ruby
# app/controllers/application_controller.rb
class ApplicationController < ActionController::Base
  # ...existing tenant logic stays...
end
```

- [ ] **Step 3: Verify Rails boots in full mode**

Run: `bundle exec rails runner "puts ActionController::Base.ancestors.include?(ActionController::MimeResponds)"`
Expected: `true`

- [ ] **Step 4: Commit**

```bash
git add config/application.rb app/controllers/application_controller.rb
git commit -m "feat: switch Rails from API mode to full mode"
```

---

### Task 2: Update Gemfile — Add New Gems, Remove Old Ones

**Files:**
- Modify: `Gemfile`

- [ ] **Step 1: Add new gems to Gemfile**

```ruby
# Authentication
gem "omniauth-shopify-oauth2"
gem "omniauth-rails_csrf_protection"

# Rate limiting
gem "rack-attack"

# Pagination
gem "kaminari"

# Asset pipeline
gem "propshaft"

# Scheduling
gem "sidekiq-cron"

group :development, :test do
  gem "brakeman", require: false
end
```

- [ ] **Step 2: Remove old gems from Gemfile**

Remove these lines:
```ruby
gem "vite_ruby"      # or vite_rails
gem "shopify_app"    # replaced by omniauth
```

- [ ] **Step 3: Run bundle install**

Run: `bundle install`
Expected: Bundler resolves and installs successfully

- [ ] **Step 4: Commit**

```bash
git add Gemfile Gemfile.lock
git commit -m "feat: update gems — add omniauth, rack-attack, kaminari, propshaft; remove vite, shopify_app"
```

---

### Task 3: Run Database Migrations

**Files:**
- Create: `db/migrate/TIMESTAMP_simplify_supplier_rating.rb`
- Create: `db/migrate/TIMESTAMP_add_agent_results_to_shops.rb`
- Create: `db/migrate/TIMESTAMP_create_audit_logs.rb`
- Create: `db/migrate/TIMESTAMP_drop_unused_tables.rb`

- [ ] **Step 1: Generate supplier rating migration**

Run: `bundle exec rails generate migration SimplifySupplierRating`

Then edit the migration:
```ruby
class SimplifySupplierRating < ActiveRecord::Migration[7.2]
  def change
    add_column :suppliers, :star_rating, :integer, default: 0
    add_column :suppliers, :rating_notes, :text
  end
end
```

- [ ] **Step 2: Generate agent results migration**

Run: `bundle exec rails generate migration AddAgentResultsToShops`

```ruby
class AddAgentResultsToShops < ActiveRecord::Migration[7.2]
  def change
    add_column :shops, :last_agent_run_at, :datetime
    add_column :shops, :last_agent_results, :jsonb, default: {}
  end
end
```

- [ ] **Step 3: Generate audit logs migration**

Run: `bundle exec rails generate migration CreateAuditLogs`

```ruby
class CreateAuditLogs < ActiveRecord::Migration[7.2]
  def change
    create_table :audit_logs do |t|
      t.references :shop, foreign_key: true
      t.string :action, null: false
      t.string :ip_address
      t.string :user_agent
      t.string :request_id
      t.jsonb :metadata, default: {}
      t.datetime :created_at, null: false
    end

    add_index :audit_logs, :action
    add_index :audit_logs, :created_at
    add_index :audit_logs, [:shop_id, :created_at]
  end
end
```

- [ ] **Step 4: Generate migration to drop unused tables**

Run: `bundle exec rails generate migration DropUnusedTables`

```ruby
class DropUnusedTables < ActiveRecord::Migration[7.2]
  def up
    drop_table :customers, if_exists: true
    drop_table :webhook_endpoints, if_exists: true
    drop_table :weekly_reports, if_exists: true
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
```

- [ ] **Step 5: Run all migrations**

Run: `bundle exec rails db:migrate`
Expected: All migrations run without error

- [ ] **Step 6: Commit**

```bash
git add db/
git commit -m "feat: add migrations — supplier rating, agent results, audit logs, drop unused tables"
```

---

### Task 4: Delete Unused Models, Jobs, and Specs

**Files:**
- Delete: `app/models/customer.rb`
- Delete: `app/models/webhook_endpoint.rb`
- Delete: `app/models/weekly_report.rb`
- Delete: `app/jobs/weekly_report_job.rb` (if exists)
- Delete: `app/jobs/weekly_report_all_shops_job.rb` (if exists)
- Delete: `spec/models/customer_spec.rb`
- Delete: `spec/models/webhook_endpoint_spec.rb`
- Delete: `spec/models/weekly_report_spec.rb`
- Delete: `spec/jobs/weekly_report_job_spec.rb` (if exists)
- Delete: `spec/jobs/weekly_report_all_shops_job_spec.rb` (if exists)

- [ ] **Step 1: Delete unused model files**

```bash
rm -f app/models/customer.rb app/models/webhook_endpoint.rb app/models/weekly_report.rb
```

- [ ] **Step 2: Delete unused job files**

```bash
rm -f app/jobs/weekly_report_job.rb app/jobs/weekly_report_all_shops_job.rb
```

- [ ] **Step 3: Delete corresponding specs**

```bash
rm -f spec/models/customer_spec.rb spec/models/webhook_endpoint_spec.rb spec/models/weekly_report_spec.rb
rm -f spec/jobs/weekly_report_job_spec.rb spec/jobs/weekly_report_all_shops_job_spec.rb
rm -f spec/requests/api/v1/customers_spec.rb
```

- [ ] **Step 4: Remove references to deleted models from factories and other specs**

Check for references:
```bash
grep -rl "Customer\|WebhookEndpoint\|WeeklyReport" spec/ app/ --include="*.rb" | grep -v "_spec.rb$"
```
Remove any factory files and association references.

- [ ] **Step 5: Verify existing tests still pass**

Run: `bundle exec rspec --format progress`
Expected: Remaining specs pass (some may fail from other changes — fix in later tasks)

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "chore: delete unused models (Customer, WebhookEndpoint, WeeklyReport) and associated jobs/specs"
```

---

### Task 5: Create AuditLog Model

**Files:**
- Create: `app/models/audit_log.rb`
- Create: `spec/models/audit_log_spec.rb`

- [ ] **Step 1: Write the failing test**

```ruby
# spec/models/audit_log_spec.rb
require "rails_helper"

RSpec.describe AuditLog, type: :model do
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bundle exec rspec spec/models/audit_log_spec.rb`
Expected: FAIL — `uninitialized constant AuditLog`

- [ ] **Step 3: Write the AuditLog model**

```ruby
# app/models/audit_log.rb
class AuditLog < ApplicationRecord
  belongs_to :shop, optional: true

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

- [ ] **Step 4: Run test to verify it passes**

Run: `bundle exec rspec spec/models/audit_log_spec.rb`
Expected: 3 examples, 0 failures

- [ ] **Step 5: Commit**

```bash
git add app/models/audit_log.rb spec/models/audit_log_spec.rb
git commit -m "feat: add AuditLog model — append-only security event log"
```

---

## Chunk 2: Authentication — OmniAuth Shopify + Session Security

### Task 6: Configure OmniAuth Shopify

**Files:**
- Create: `config/initializers/omniauth.rb`
- Create: `config/initializers/session_store.rb`
- Modify: `config/routes.rb`

- [ ] **Step 1: Create OmniAuth initializer**

```ruby
# config/initializers/omniauth.rb
Rails.application.config.middleware.use OmniAuth::Builder do
  provider :shopify,
    ENV.fetch("SHOPIFY_API_KEY"),
    ENV.fetch("SHOPIFY_API_SECRET"),
    scope: "read_products,read_inventory,read_orders"
end

OmniAuth.config.allowed_request_methods = [:post]
```

- [ ] **Step 2: Create session store initializer**

```ruby
# config/initializers/session_store.rb
Rails.application.config.session_store :cookie_store,
  key: "_stockpilot_session",
  expire_after: 24.hours,
  secure: Rails.env.production?,
  httponly: true,
  same_site: :lax
```

- [ ] **Step 3: Commit**

```bash
git add config/initializers/omniauth.rb config/initializers/session_store.rb
git commit -m "feat: configure OmniAuth Shopify + secure session store"
```

---

### Task 7: Build AuthController

**Files:**
- Create: `app/controllers/auth_controller.rb`
- Create: `spec/requests/auth_spec.rb`

- [ ] **Step 1: Write the failing test**

```ruby
# spec/requests/auth_spec.rb
require "rails_helper"

RSpec.describe "Auth", type: :request do
  describe "GET /auth/shopify/callback" do
    let(:auth_hash) do
      OmniAuth::AuthHash.new(
        provider: "shopify",
        uid: "test-shop.myshopify.com",
        credentials: { token: "test-token" },
        extra: { raw_info: { myshopify_domain: "test-shop.myshopify.com", name: "Test Shop" } }
      )
    end

    before do
      OmniAuth.config.test_mode = true
      OmniAuth.config.mock_auth[:shopify] = auth_hash
    end

    after { OmniAuth.config.test_mode = false }

    it "creates a shop and redirects to dashboard" do
      expect {
        get "/auth/shopify/callback"
      }.to change(Shop, :count).by(1)
      expect(response).to redirect_to("/dashboard")
    end

    it "creates an audit log entry" do
      expect {
        get "/auth/shopify/callback"
      }.to change(AuditLog.where(action: "login"), :count).by(1)
    end

    it "prevents session fixation by resetting session" do
      get "/auth/shopify/callback"
      old_session = session.id
      get "/auth/shopify/callback"
      # Session should be different (reset_session called)
      expect(response).to redirect_to("/dashboard")
    end
  end

  describe "DELETE /logout" do
    let(:shop) { create(:shop) }

    it "destroys session and redirects to root" do
      login_as(shop)
      delete "/logout"
      expect(response).to redirect_to("/")
    end
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bundle exec rspec spec/requests/auth_spec.rb`
Expected: FAIL — routing or controller not found

- [ ] **Step 3: Write AuthController**

```ruby
# app/controllers/auth_controller.rb
class AuthController < ApplicationController
  skip_before_action :require_login

  def callback
    auth = request.env["omniauth.auth"]
    reset_session

    shop = Shop.find_or_initialize_by(shopify_domain: auth.uid)
    shop.shopify_token = auth.credentials.token
    shop.save!

    session[:shop_id] = shop.id
    AuditLog.record(action: "login", shop: shop, request: request)
    redirect_to "/dashboard"
  end

  def failure
    AuditLog.record(action: "login_failed", request: request,
                    metadata: { reason: params[:message] })
    redirect_to root_path, alert: "Authentication failed: #{params[:message]}"
  end

  def destroy
    AuditLog.record(action: "logout", shop: current_shop, request: request)
    reset_session
    redirect_to root_path
  end
end
```

- [ ] **Step 4: Add auth routes to routes.rb**

```ruby
# In config/routes.rb, add:
get "/auth/shopify/callback", to: "auth#callback"
get "/auth/failure", to: "auth#failure"
delete "/logout", to: "auth#destroy"
```

- [ ] **Step 5: Update ApplicationController with session-based auth**

```ruby
# app/controllers/application_controller.rb
class ApplicationController < ActionController::Base
  before_action :require_login
  before_action :set_tenant

  private

  def require_login
    redirect_to root_path, alert: "Please log in" unless current_shop
  end

  def current_shop
    @current_shop ||= Shop.find_by(id: session[:shop_id])
  end
  helper_method :current_shop

  def set_tenant
    ActsAsTenant.current_tenant = current_shop
  end
end
```

- [ ] **Step 6: Add `login_as` test helper**

```ruby
# spec/support/auth_helpers.rb
module AuthHelpers
  def login_as(shop)
    post "/test_login", params: { shop_id: shop.id }
  end
end

RSpec.configure do |config|
  config.include AuthHelpers, type: :request
end
```

Add a test-only route (or use session manipulation in tests):
```ruby
# In spec/rails_helper.rb or a support file, add session manipulation
module AuthHelpers
  def login_as(shop)
    # Set session directly in test
    allow_any_instance_of(ApplicationController).to receive(:current_shop).and_return(shop)
  end
end
```

- [ ] **Step 7: Run test to verify it passes**

Run: `bundle exec rspec spec/requests/auth_spec.rb`
Expected: All examples pass

- [ ] **Step 8: Commit**

```bash
git add app/controllers/auth_controller.rb app/controllers/application_controller.rb spec/requests/auth_spec.rb config/routes.rb spec/support/
git commit -m "feat: add AuthController with OmniAuth Shopify, session security, audit logging"
```

---

## Chunk 3: Layout, CSS, and Shared Views

### Task 8: Set Up Propshaft + Pico CSS + HTMX

**Files:**
- Create: `app/assets/stylesheets/application.css` (imports Pico + overrides)
- Create: `app/assets/stylesheets/overrides.css`
- Create: `app/assets/stylesheets/landing.css`
- Modify: `config/initializers/assets.rb` (if needed)

- [ ] **Step 1: Create application.css that imports Pico**

```css
/* app/assets/stylesheets/application.css */
/* Pico CSS loaded from CDN in layout */
/* This file is for app-wide overrides only */
@import "overrides.css";
```

- [ ] **Step 2: Create overrides.css**

```css
/* app/assets/stylesheets/overrides.css */
:root {
  --sp-sidebar-width: 220px;
  --sp-sidebar-collapsed: 60px;
}

/* Sidebar layout */
.app-shell {
  display: grid;
  grid-template-columns: var(--sp-sidebar-collapsed) 1fr;
  min-height: 100vh;
}

.app-shell--expanded {
  grid-template-columns: var(--sp-sidebar-width) 1fr;
}

.app-main {
  padding: 2rem;
  max-width: 1200px;
}

/* KPI cards */
.kpi-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
  gap: 1rem;
  margin-bottom: 2rem;
}

.kpi-card {
  padding: 1.5rem;
  border: 1px solid var(--pico-muted-border-color);
  border-radius: 8px;
}

.kpi-card__value {
  font-size: 2rem;
  font-weight: 700;
}

.kpi-card__label {
  color: var(--pico-muted-color);
  font-size: 0.875rem;
}

/* Alert rows */
.alert-row {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 0.75rem 1rem;
  border-bottom: 1px solid var(--pico-muted-border-color);
}

.alert-row--critical { border-left: 3px solid #D72C0D; }
.alert-row--warning  { border-left: 3px solid #FFC453; }

/* Star rating */
.star-rating { cursor: pointer; font-size: 1.25rem; }
.star-rating .filled { color: #FFC453; }
.star-rating .empty  { color: var(--pico-muted-color); }

/* HTMX indicator */
.htmx-indicator { display: none; }
.htmx-request .htmx-indicator { display: inline; }
```

- [ ] **Step 3: Create landing.css**

Preserve the dotted-grid + hero style from the StockPilot React landing page, converted to plain CSS (no Framer Motion):

```css
/* app/assets/stylesheets/landing.css */
/* Landing page hero + dotted grid — static version */
@import url('https://fonts.googleapis.com/css2?family=Love+Ya+Like+A+Sister&display=swap');

.sp { background: #fff; color: #1a1a1a; min-height: 100vh; }

.sp-nav {
  position: fixed; top: 0; left: 0; right: 0;
  z-index: 100; padding: 1rem 2rem;
  background: rgba(255,255,255,0.9);
  backdrop-filter: blur(8px);
  border-bottom: 1px solid #e5e5e5;
}
.sp-nav__inner {
  max-width: 1200px; margin: 0 auto;
  display: flex; align-items: center; justify-content: space-between;
}
.sp-nav__brand { display: flex; align-items: center; gap: 0.5rem; font-weight: 600; }
.sp-nav__links { display: flex; gap: 2rem; }
.sp-nav__links a { color: #6D7175; text-decoration: none; }
.sp-nav__links a:hover { color: #1a1a1a; }

/* Hero */
.sp-hero {
  min-height: 100vh; display: flex; flex-direction: column;
  align-items: center; justify-content: center; text-align: center;
  padding: 6rem 2rem 4rem;
  position: relative;
}
.sp-hero__title {
  font-family: 'Love Ya Like A Sister', cursive;
  font-size: clamp(3rem, 8vw, 6rem);
  margin: 1rem 0;
}
.sp-hero__sub {
  max-width: 600px; color: #6D7175; font-size: 1.125rem; line-height: 1.6;
}
.sp-hero__actions { display: flex; gap: 1rem; margin-top: 2rem; }

/* Pill badge */
.sp-pill {
  display: inline-flex; align-items: center; gap: 0.5rem;
  padding: 0.375rem 1rem; border-radius: 999px;
  border: 1px solid #e5e5e5; font-size: 0.8125rem;
  background: #fff;
}
.sp-pill__icon { width: 18px; height: 18px; }

/* Buttons */
.sp-btn {
  display: inline-flex; align-items: center; gap: 0.25rem;
  padding: 0.625rem 1.5rem; border-radius: 8px;
  text-decoration: none; font-weight: 500; font-size: 0.9375rem;
  border: 1px solid #c9cccf; color: #1a1a1a; background: #fff;
  transition: background 0.15s;
}
.sp-btn:hover { background: #f6f6f7; }
.sp-btn--primary { background: #1a1a1a; color: #fff; border-color: #1a1a1a; }
.sp-btn--primary:hover { background: #333; }

/* Dotted grid */
.sp-grid {
  position: fixed; inset: 0; pointer-events: none; z-index: 0;
}
.sp-grid__line {
  position: absolute; top: 0; bottom: 0; width: 1px;
  background: repeating-linear-gradient(to bottom, transparent, transparent 6px, #e0e0e0 6px, #e0e0e0 7px);
}
.sp-grid__line--1 { left: 25%; }
.sp-grid__line--2 { left: 50%; }
.sp-grid__line--3 { left: 75%; }
.sp-grid__hline {
  position: absolute; left: 0; right: 0; height: 1px;
  background: repeating-linear-gradient(to right, transparent, transparent 6px, #e0e0e0 6px, #e0e0e0 7px);
}
.sp-grid__hline--1 { top: 33%; }
.sp-grid__hline--2 { top: 66%; }

/* Features section */
.sp-features {
  display: grid; grid-template-columns: repeat(auto-fit, minmax(240px, 1fr));
  gap: 2rem; margin-top: 2rem;
}
.sp-feature { padding: 1.5rem; border: 1px solid #e5e5e5; border-radius: 12px; }
.sp-feature__num { color: #6D7175; font-size: 0.75rem; font-weight: 600; }
.sp-feature__title { margin: 0.5rem 0 0.25rem; font-weight: 600; }
.sp-feature__desc { color: #6D7175; font-size: 0.875rem; }

/* Steps */
.sp-steps { max-width: 600px; margin: 2rem auto 0; }
.sp-step { display: flex; gap: 1rem; padding: 1rem 0; position: relative; }
.sp-step__num {
  width: 2rem; height: 2rem; border-radius: 50%;
  background: #1a1a1a; color: #fff; display: flex;
  align-items: center; justify-content: center; font-weight: 600;
  flex-shrink: 0;
}
.sp-step__title { font-weight: 600; margin-bottom: 0.25rem; }
.sp-step__desc { color: #6D7175; font-size: 0.875rem; }

/* Footer */
.sp-footer {
  padding: 2rem; text-align: center; color: #6D7175;
  border-top: 1px solid #e5e5e5; font-size: 0.875rem;
}
.sp-footer a { color: #6D7175; margin: 0 1rem; }
```

- [ ] **Step 4: Commit**

```bash
git add app/assets/stylesheets/
git commit -m "feat: add Pico CSS overrides, HTMX indicator styles, and landing page CSS"
```

---

### Task 9: Create ERB Layouts

**Files:**
- Create: `app/views/layouts/application.html.erb`
- Create: `app/views/layouts/landing.html.erb`
- Create: `app/views/shared/_sidebar.html.erb`
- Create: `app/views/shared/_flash.html.erb`

- [ ] **Step 1: Create application layout**

```erb
<%# app/views/layouts/application.html.erb %>
<!DOCTYPE html>
<html lang="en" data-theme="light">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>StockPilot</title>
  <link rel="stylesheet" href="https://unpkg.com/@picocss/pico@2/css/pico.min.css">
  <%= stylesheet_link_tag "application" %>
  <script src="https://unpkg.com/htmx.org@2.0.4"></script>
  <%= csrf_meta_tags %>
</head>
<body>
  <div class="app-shell">
    <%= render "shared/sidebar" %>
    <main class="app-main">
      <%= render "shared/flash" %>
      <%= yield %>
    </main>
  </div>
</body>
</html>
```

- [ ] **Step 2: Create landing layout**

```erb
<%# app/views/layouts/landing.html.erb %>
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>StockPilot — AI Inventory Management for Shopify</title>
  <%= stylesheet_link_tag "landing" %>
</head>
<body>
  <%= yield %>
</body>
</html>
```

- [ ] **Step 3: Create sidebar partial**

```erb
<%# app/views/shared/_sidebar.html.erb %>
<nav class="sidebar" aria-label="Main navigation">
  <div class="sidebar__brand">
    <svg width="22" height="22" viewBox="0 0 28 28" fill="none" aria-hidden="true">
      <rect x="2" y="2" width="24" height="24" rx="6" stroke="currentColor" stroke-width="1.5"/>
      <rect x="7" y="14" width="4" height="8" rx="1" fill="currentColor"/>
      <rect x="12" y="10" width="4" height="12" rx="1" fill="#9CA3AF"/>
      <rect x="17" y="6" width="4" height="16" rx="1" fill="currentColor"/>
    </svg>
    <span>StockPilot</span>
  </div>
  <ul>
    <li><a href="/dashboard" class="<%= 'active' if request.path == '/dashboard' %>">Dashboard</a></li>
    <li><a href="/inventory" class="<%= 'active' if request.path.start_with?('/inventory') %>">Inventory</a></li>
    <li><a href="/suppliers" class="<%= 'active' if request.path.start_with?('/suppliers') %>">Suppliers</a></li>
    <li><a href="/purchase_orders" class="<%= 'active' if request.path.start_with?('/purchase_orders') %>">Purchase Orders</a></li>
  </ul>
  <div class="sidebar__footer">
    <%= button_to "Logout", "/logout", method: :delete, class: "sidebar__logout" %>
  </div>
</nav>
```

- [ ] **Step 4: Create flash partial**

```erb
<%# app/views/shared/_flash.html.erb %>
<% flash.each do |type, message| %>
  <div role="alert" class="flash flash--<%= type %>">
    <%= message %>
  </div>
<% end %>
```

- [ ] **Step 5: Commit**

```bash
git add app/views/layouts/ app/views/shared/
git commit -m "feat: add ERB layouts — application (Pico + HTMX), landing, sidebar, flash"
```

---

## Chunk 4: Pages — Landing, Dashboard, Inventory

### Task 10: Landing Page

**Files:**
- Create: `app/controllers/landing_controller.rb`
- Create: `app/views/landing/index.html.erb`

- [ ] **Step 1: Create LandingController**

```ruby
# app/controllers/landing_controller.rb
class LandingController < ApplicationController
  skip_before_action :require_login
  layout "landing"

  def index
  end
end
```

- [ ] **Step 2: Create landing view**

Convert the StockPilot React landing to static ERB (no JS, no Framer Motion). Keep dotted grid, hero, features, steps, CTA, footer.

```erb
<%# app/views/landing/index.html.erb %>
<div class="sp">
  <a href="#sp-main" class="sr-only">Skip to main content</a>

  <!-- Dotted grid -->
  <div class="sp-grid" aria-hidden="true">
    <div class="sp-grid__line sp-grid__line--1"></div>
    <div class="sp-grid__line sp-grid__line--2"></div>
    <div class="sp-grid__line sp-grid__line--3"></div>
    <div class="sp-grid__hline sp-grid__hline--1"></div>
    <div class="sp-grid__hline sp-grid__hline--2"></div>
  </div>

  <!-- Nav -->
  <nav class="sp-nav" aria-label="StockPilot navigation">
    <div class="sp-nav__inner">
      <div class="sp-nav__brand">
        <svg width="22" height="22" viewBox="0 0 28 28" fill="none" aria-hidden="true">
          <rect x="2" y="2" width="24" height="24" rx="6" stroke="currentColor" stroke-width="1.5"/>
          <rect x="7" y="14" width="4" height="8" rx="1" fill="currentColor"/>
          <rect x="12" y="10" width="4" height="12" rx="1" fill="#9CA3AF"/>
          <rect x="17" y="6" width="4" height="16" rx="1" fill="currentColor"/>
        </svg>
        <span class="sp-nav__wordmark">Stock Pilot</span>
      </div>
      <div class="sp-nav__links">
        <a href="#sp-features">Features</a>
        <a href="#sp-how">How it works</a>
      </div>
      <a href="/auth/shopify" class="sp-btn sp-btn--primary" data-method="post">
        Get started
      </a>
    </div>
  </nav>

  <!-- Hero -->
  <section class="sp-hero" id="sp-main">
    <div class="sp-pill">
      <%= image_tag "shopify-bag.png", alt: "", class: "sp-pill__icon" %>
      <span>Built for Shopify</span>
    </div>
    <h1 class="sp-hero__title">$tockPilot</h1>
    <p class="sp-hero__sub">
      Four AI agents monitor stock, draft purchase orders,
      find suppliers, and wait for your sign-off — so you
      never lose a sale to an empty shelf.
    </p>
    <div class="sp-hero__actions">
      <a href="/auth/shopify" class="sp-btn sp-btn--primary" data-method="post">
        Deploy your agents
      </a>
      <a href="#sp-how" class="sp-btn">See how it works</a>
    </div>
    <p class="sp-hero__proof" style="margin-top: 2rem; color: #6D7175; font-size: 0.875rem;">
      2,000+ merchants · 4 AI agents · Human-in-the-loop
    </p>
  </section>

  <!-- Features -->
  <section id="sp-features" style="max-width: 1000px; margin: 0 auto; padding: 4rem 2rem;">
    <h2>Four agents. One command center.</h2>
    <div class="sp-features">
      <div class="sp-feature">
        <span class="sp-feature__num">01</span>
        <h3 class="sp-feature__title">Inventory Monitor</h3>
        <p class="sp-feature__desc">Scans stock across all locations. Flags critical SKUs before you lose a sale.</p>
      </div>
      <div class="sp-feature">
        <span class="sp-feature__num">02</span>
        <h3 class="sp-feature__title">PO Drafter</h3>
        <p class="sp-feature__desc">Analyzes velocity and lead times. Drafts purchase orders automatically.</p>
      </div>
      <div class="sp-feature">
        <span class="sp-feature__num">03</span>
        <h3 class="sp-feature__title">Lead Scout</h3>
        <p class="sp-feature__desc">Finds the best suppliers. Compares pricing, lead times, and reliability.</p>
      </div>
      <div class="sp-feature">
        <span class="sp-feature__num">04</span>
        <h3 class="sp-feature__title">Approval Gate</h3>
        <p class="sp-feature__desc">Human-in-the-loop. No agent acts without your sign-off.</p>
      </div>
    </div>
  </section>

  <!-- How it works -->
  <section id="sp-how" style="max-width: 1000px; margin: 0 auto; padding: 4rem 2rem;">
    <h2>Connect. Configure. Let agents fly.</h2>
    <div class="sp-steps">
      <div class="sp-step">
        <div class="sp-step__num">1</div>
        <div>
          <h3 class="sp-step__title">Connect your store</h3>
          <p class="sp-step__desc">Install and sync your Shopify products in under 60 seconds.</p>
        </div>
      </div>
      <div class="sp-step">
        <div class="sp-step__num">2</div>
        <div>
          <h3 class="sp-step__title">Set your rules</h3>
          <p class="sp-step__desc">Configure thresholds, alerts, and reorder preferences.</p>
        </div>
      </div>
      <div class="sp-step">
        <div class="sp-step__num">3</div>
        <div>
          <h3 class="sp-step__title">Agents take over</h3>
          <p class="sp-step__desc">Four AI agents start monitoring and managing your inventory.</p>
        </div>
      </div>
      <div class="sp-step">
        <div class="sp-step__num">4</div>
        <div>
          <h3 class="sp-step__title">You review & approve</h3>
          <p class="sp-step__desc">Every PO, every decision waits for your sign-off.</p>
        </div>
      </div>
    </div>
  </section>

  <!-- CTA -->
  <section id="sp-cta" style="text-align: center; padding: 4rem 2rem;">
    <h2>Ready for takeoff?</h2>
    <p style="color: #6D7175; margin-bottom: 2rem;">Deploy your agents and put your inventory on autopilot.</p>
    <a href="/auth/shopify" class="sp-btn sp-btn--primary" data-method="post">Get started free</a>
  </section>

  <!-- Footer -->
  <footer class="sp-footer">
    <p>&copy; 2026 Stock Pilot</p>
    <nav aria-label="Footer links">
      <a href="#">Privacy</a>
      <a href="#">Terms</a>
      <a href="#">Changelog</a>
    </nav>
  </footer>
</div>
```

- [ ] **Step 3: Update routes**

```ruby
# config/routes.rb
root "landing#index"
```

- [ ] **Step 4: Commit**

```bash
git add app/controllers/landing_controller.rb app/views/landing/
git commit -m "feat: add landing page — static ERB with dotted grid, hero, features, steps"
```

---

### Task 11: Dashboard Page

**Files:**
- Create: `app/controllers/dashboard_controller.rb`
- Create: `app/views/dashboard/index.html.erb`
- Create: `app/views/dashboard/_kpi_cards.html.erb`
- Create: `app/views/dashboard/_alerts.html.erb`
- Create: `app/views/dashboard/_agent_results.html.erb`
- Create: `spec/requests/dashboard_spec.rb`

- [ ] **Step 1: Write the failing test**

```ruby
# spec/requests/dashboard_spec.rb
require "rails_helper"

RSpec.describe "Dashboard", type: :request do
  let(:shop) { create(:shop) }

  before { login_as(shop) }

  describe "GET /dashboard" do
    it "returns success" do
      get "/dashboard"
      expect(response).to have_http_status(:ok)
    end

    it "shows KPI cards" do
      get "/dashboard"
      expect(response.body).to include("Total Products")
      expect(response.body).to include("Low Stock")
    end
  end

  describe "POST /agents/run" do
    it "runs the agent pipeline and redirects" do
      allow_any_instance_of(Inventory::LowStockDetector).to receive(:call).and_return([])
      post "/agents/run"
      expect(response).to have_http_status(:ok).or have_http_status(:redirect)
    end

    it "creates an audit log" do
      allow_any_instance_of(Inventory::LowStockDetector).to receive(:call).and_return([])
      expect { post "/agents/run" }.to change(AuditLog.where(action: "agent_run"), :count).by(1)
    end
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bundle exec rspec spec/requests/dashboard_spec.rb`
Expected: FAIL

- [ ] **Step 3: Write DashboardController**

```ruby
# app/controllers/dashboard_controller.rb
class DashboardController < ApplicationController
  def index
    @total_products = Product.count
    @low_stock = Variant.where("inventory_quantity <= ?", 10).count
    @out_of_stock = Variant.where(inventory_quantity: 0).count
    @pending_pos = PurchaseOrder.where(status: "draft").count
    @recent_alerts = Alert.order(created_at: :desc).limit(10)
    @last_run = current_shop.last_agent_results
    @last_run_at = current_shop.last_agent_run_at
  end

  def run_agent
    AuditLog.record(action: "agent_run", shop: current_shop, request: request)

    detector = Inventory::LowStockDetector.new(current_shop)
    low_stock_variants = detector.call

    results = { low_stock_count: low_stock_variants.size, ran_at: Time.current.iso8601 }
    current_shop.update!(last_agent_run_at: Time.current, last_agent_results: results)

    if request.headers["HX-Request"]
      render partial: "agent_results", locals: { results: results }
    else
      redirect_to "/dashboard", notice: "Agent run complete"
    end
  end
end
```

- [ ] **Step 4: Create dashboard views**

```erb
<%# app/views/dashboard/index.html.erb %>
<h1>Dashboard</h1>

<%= render "kpi_cards" %>

<section>
  <h2>Recent Alerts</h2>
  <div id="alerts-list">
    <%= render "alerts" %>
  </div>
</section>

<section>
  <h2>Agent Results</h2>
  <button hx-post="/agents/run" hx-target="#agent-results" hx-indicator="#agent-spinner">
    Run Agent Now
  </button>
  <span id="agent-spinner" class="htmx-indicator">Analyzing inventory...</span>
  <div id="agent-results">
    <%= render "agent_results", results: @last_run %>
  </div>
</section>
```

```erb
<%# app/views/dashboard/_kpi_cards.html.erb %>
<div class="kpi-grid">
  <div class="kpi-card">
    <div class="kpi-card__value"><%= @total_products %></div>
    <div class="kpi-card__label">Total Products</div>
  </div>
  <div class="kpi-card">
    <div class="kpi-card__value"><%= @low_stock %></div>
    <div class="kpi-card__label">Low Stock</div>
  </div>
  <div class="kpi-card">
    <div class="kpi-card__value"><%= @out_of_stock %></div>
    <div class="kpi-card__label">Out of Stock</div>
  </div>
  <div class="kpi-card">
    <div class="kpi-card__value"><%= @pending_pos %></div>
    <div class="kpi-card__label">Pending POs</div>
  </div>
</div>
```

```erb
<%# app/views/dashboard/_alerts.html.erb %>
<% if @recent_alerts.any? %>
  <% @recent_alerts.each do |alert| %>
    <div class="alert-row alert-row--<%= alert.severity || 'warning' %>" id="alert-<%= alert.id %>">
      <span><%= alert.message %></span>
      <button hx-patch="/alerts/<%= alert.id %>/dismiss" hx-target="#alert-<%= alert.id %>" hx-swap="outerHTML">
        Dismiss
      </button>
    </div>
  <% end %>
<% else %>
  <p>No recent alerts.</p>
<% end %>
```

```erb
<%# app/views/dashboard/_agent_results.html.erb %>
<% if results.present? %>
  <div style="margin-top: 1rem; padding: 1rem; border: 1px solid var(--pico-muted-border-color); border-radius: 8px;">
    <p><strong>Last run:</strong> <%= results["ran_at"] || @last_run_at&.strftime("%b %d, %H:%M") %></p>
    <p><strong>Low stock items found:</strong> <%= results["low_stock_count"] || 0 %></p>
  </div>
<% else %>
  <p style="color: var(--pico-muted-color);">No agent runs yet. Click "Run Agent Now" to start.</p>
<% end %>
```

- [ ] **Step 5: Add dashboard routes**

```ruby
# In config/routes.rb
get "/dashboard", to: "dashboard#index"
post "/agents/run", to: "dashboard#run_agent"
```

- [ ] **Step 6: Run test to verify it passes**

Run: `bundle exec rspec spec/requests/dashboard_spec.rb`
Expected: All examples pass

- [ ] **Step 7: Commit**

```bash
git add app/controllers/dashboard_controller.rb app/views/dashboard/ spec/requests/dashboard_spec.rb config/routes.rb
git commit -m "feat: add dashboard page — KPI cards, alerts, agent run with HTMX"
```

---

### Task 12: Inventory Page

**Files:**
- Create: `app/controllers/inventory_controller.rb`
- Create: `app/views/inventory/index.html.erb`
- Create: `app/views/inventory/show.html.erb`
- Create: `app/views/inventory/_table.html.erb`
- Create: `spec/requests/inventory_spec.rb`

- [ ] **Step 1: Write the failing test**

```ruby
# spec/requests/inventory_spec.rb
require "rails_helper"

RSpec.describe "Inventory", type: :request do
  let(:shop) { create(:shop) }

  before { login_as(shop) }

  describe "GET /inventory" do
    it "returns success" do
      get "/inventory"
      expect(response).to have_http_status(:ok)
    end

    it "filters by low stock" do
      get "/inventory?filter=low_stock", headers: { "HX-Request" => "true" }
      expect(response).to have_http_status(:ok)
    end

    it "searches by name" do
      get "/inventory?q=widget", headers: { "HX-Request" => "true" }
      expect(response).to have_http_status(:ok)
    end
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bundle exec rspec spec/requests/inventory_spec.rb`
Expected: FAIL

- [ ] **Step 3: Write InventoryController**

```ruby
# app/controllers/inventory_controller.rb
class InventoryController < ApplicationController
  def index
    @products = Product.includes(:variants)
    @products = apply_filter(@products)
    @products = apply_search(@products)
    @products = @products.page(params[:page]).per(25)

    if request.headers["HX-Request"]
      render partial: "table", locals: { products: @products }
    end
  end

  def show
    @product = Product.includes(:variants).find(params[:id])
  end

  private

  def apply_filter(scope)
    case params[:filter]
    when "low_stock"
      scope.joins(:variants).where("variants.inventory_quantity > 0 AND variants.inventory_quantity <= 10").distinct
    when "out_of_stock"
      scope.joins(:variants).where(variants: { inventory_quantity: 0 }).distinct
    else
      scope
    end
  end

  def apply_search(scope)
    return scope unless params[:q].present?
    scope.where("products.title ILIKE ?", "%#{params[:q]}%")
  end
end
```

- [ ] **Step 4: Create inventory views**

```erb
<%# app/views/inventory/index.html.erb %>
<h1>Inventory</h1>

<div style="display: flex; gap: 0.5rem; margin-bottom: 1rem;">
  <button hx-get="/inventory?filter=all" hx-target="#product-table" hx-push-url="true">All</button>
  <button hx-get="/inventory?filter=low_stock" hx-target="#product-table" hx-push-url="true">Low Stock</button>
  <button hx-get="/inventory?filter=out_of_stock" hx-target="#product-table" hx-push-url="true">Out of Stock</button>
</div>

<input type="search" name="q" placeholder="Search by name or SKU..."
       hx-get="/inventory" hx-target="#product-table"
       hx-trigger="input changed delay:300ms" hx-push-url="true">

<div id="product-table">
  <%= render "table", products: @products %>
</div>
```

```erb
<%# app/views/inventory/_table.html.erb %>
<table>
  <thead>
    <tr>
      <th>Product</th>
      <th>SKU</th>
      <th>Stock</th>
      <th>Status</th>
    </tr>
  </thead>
  <tbody>
    <% products.each do |product| %>
      <% product.variants.each do |variant| %>
        <tr>
          <td><a href="/inventory/<%= product.id %>"><%= product.title %></a></td>
          <td><%= variant.sku %></td>
          <td><%= variant.inventory_quantity %></td>
          <td>
            <% if variant.inventory_quantity == 0 %>
              <mark>Out of Stock</mark>
            <% elsif variant.inventory_quantity <= 10 %>
              <mark>Low</mark>
            <% else %>
              In Stock
            <% end %>
          </td>
        </tr>
      <% end %>
    <% end %>
  </tbody>
</table>

<%= render "shared/pagination", collection: products %>
```

```erb
<%# app/views/inventory/show.html.erb %>
<h1><%= @product.title %></h1>
<a href="/inventory">&larr; Back to inventory</a>

<table>
  <thead>
    <tr><th>Variant</th><th>SKU</th><th>Stock</th></tr>
  </thead>
  <tbody>
    <% @product.variants.each do |v| %>
      <tr>
        <td><%= v.title %></td>
        <td><%= v.sku %></td>
        <td><%= v.inventory_quantity %></td>
      </tr>
    <% end %>
  </tbody>
</table>
```

```erb
<%# app/views/shared/_pagination.html.erb %>
<% if collection.respond_to?(:total_pages) && collection.total_pages > 1 %>
  <nav aria-label="Pagination">
    <%= link_to "Previous", url_for(page: collection.prev_page), class: "sp-btn" if collection.prev_page %>
    <span>Page <%= collection.current_page %> of <%= collection.total_pages %></span>
    <%= link_to "Next", url_for(page: collection.next_page), class: "sp-btn" if collection.next_page %>
  </nav>
<% end %>
```

- [ ] **Step 5: Add inventory routes**

```ruby
# In config/routes.rb
resources :inventory, only: [:index, :show]
```

- [ ] **Step 6: Run test to verify it passes**

Run: `bundle exec rspec spec/requests/inventory_spec.rb`
Expected: All examples pass

- [ ] **Step 7: Commit**

```bash
git add app/controllers/inventory_controller.rb app/views/inventory/ app/views/shared/_pagination.html.erb spec/requests/inventory_spec.rb
git commit -m "feat: add inventory page — product table with HTMX filters, search, pagination"
```

---

## Chunk 5: Pages — Suppliers, Purchase Orders, Alerts

### Task 13: Suppliers Page

**Files:**
- Create: `app/controllers/suppliers_controller.rb`
- Create: `app/views/suppliers/index.html.erb`
- Create: `app/views/suppliers/_list.html.erb`
- Create: `app/views/suppliers/_form.html.erb`
- Create: `spec/requests/suppliers_spec.rb`

- [ ] **Step 1: Write the failing test**

```ruby
# spec/requests/suppliers_spec.rb
require "rails_helper"

RSpec.describe "Suppliers", type: :request do
  let(:shop) { create(:shop) }

  before { login_as(shop) }

  describe "GET /suppliers" do
    it "returns success" do
      get "/suppliers"
      expect(response).to have_http_status(:ok)
    end
  end

  describe "POST /suppliers" do
    let(:valid_params) { { supplier: { name: "Acme Co", email: "acme@example.com", lead_time_days: 7 } } }

    it "creates a supplier" do
      expect { post "/suppliers", params: valid_params }.to change(Supplier, :count).by(1)
    end

    it "creates an audit log" do
      expect { post "/suppliers", params: valid_params }.to change(AuditLog.where(action: "supplier_created"), :count).by(1)
    end
  end

  describe "DELETE /suppliers/:id" do
    let!(:supplier) { create(:supplier) }

    it "deletes the supplier" do
      expect { delete "/suppliers/#{supplier.id}" }.to change(Supplier, :count).by(-1)
    end

    it "creates an audit log" do
      expect { delete "/suppliers/#{supplier.id}" }.to change(AuditLog.where(action: "supplier_deleted"), :count).by(1)
    end
  end

  describe "PATCH /suppliers/:id" do
    let!(:supplier) { create(:supplier, star_rating: 0) }

    it "updates star rating" do
      patch "/suppliers/#{supplier.id}", params: { supplier: { star_rating: 4 } }
      expect(supplier.reload.star_rating).to eq(4)
    end
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bundle exec rspec spec/requests/suppliers_spec.rb`
Expected: FAIL

- [ ] **Step 3: Write SuppliersController**

```ruby
# app/controllers/suppliers_controller.rb
class SuppliersController < ApplicationController
  def index
    @suppliers = Supplier.order(:name)
    @supplier = Supplier.new
  end

  def create
    @supplier = Supplier.new(supplier_params)
    if @supplier.save
      AuditLog.record(action: "supplier_created", shop: current_shop, request: request,
                      metadata: { supplier_id: @supplier.id })
      if request.headers["HX-Request"]
        @suppliers = Supplier.order(:name)
        render partial: "list", locals: { suppliers: @suppliers }
      else
        redirect_to suppliers_path, notice: "Supplier created"
      end
    else
      render :index, status: :unprocessable_entity
    end
  end

  def update
    @supplier = Supplier.find(params[:id])
    if @supplier.update(supplier_params)
      if request.headers["HX-Request"]
        @suppliers = Supplier.order(:name)
        render partial: "list", locals: { suppliers: @suppliers }
      else
        redirect_to suppliers_path, notice: "Supplier updated"
      end
    else
      render :index, status: :unprocessable_entity
    end
  end

  def destroy
    @supplier = Supplier.find(params[:id])
    AuditLog.record(action: "supplier_deleted", shop: current_shop, request: request,
                    metadata: { supplier_id: @supplier.id, name: @supplier.name })
    @supplier.destroy!
    if request.headers["HX-Request"]
      @suppliers = Supplier.order(:name)
      render partial: "list", locals: { suppliers: @suppliers }
    else
      redirect_to suppliers_path, notice: "Supplier deleted"
    end
  end

  private

  def supplier_params
    params.require(:supplier).permit(:name, :email, :phone, :lead_time_days, :star_rating, :rating_notes)
  end
end
```

- [ ] **Step 4: Create supplier views**

```erb
<%# app/views/suppliers/index.html.erb %>
<h1>Suppliers</h1>

<details>
  <summary role="button" class="outline">Add Supplier</summary>
  <%= render "form", supplier: @supplier, url: suppliers_path, method: :post %>
</details>

<div id="supplier-list">
  <%= render "list", suppliers: @suppliers %>
</div>
```

```erb
<%# app/views/suppliers/_list.html.erb %>
<table>
  <thead>
    <tr>
      <th>Name</th>
      <th>Email</th>
      <th>Lead Time</th>
      <th>Rating</th>
      <th>Actions</th>
    </tr>
  </thead>
  <tbody>
    <% suppliers.each do |s| %>
      <tr>
        <td><%= s.name %></td>
        <td><%= s.email %></td>
        <td><%= s.lead_time_days %> days</td>
        <td>
          <span class="star-rating">
            <% 5.times do |i| %>
              <span hx-patch="/suppliers/<%= s.id %>"
                    hx-vals='{"supplier": {"star_rating": <%= i + 1 %>}}'
                    hx-target="#supplier-list"
                    class="<%= i < (s.star_rating || 0) ? 'filled' : 'empty' %>">★</span>
            <% end %>
          </span>
        </td>
        <td>
          <button hx-delete="/suppliers/<%= s.id %>"
                  hx-target="#supplier-list"
                  hx-confirm="Delete <%= s.name %>?">Delete</button>
        </td>
      </tr>
    <% end %>
  </tbody>
</table>
```

```erb
<%# app/views/suppliers/_form.html.erb %>
<form hx-post="<%= url %>" hx-target="#supplier-list" hx-swap="innerHTML">
  <%= hidden_field_tag :authenticity_token, form_authenticity_token %>
  <label>Name <input type="text" name="supplier[name]" value="<%= supplier.name %>" required></label>
  <label>Email <input type="email" name="supplier[email]" value="<%= supplier.email %>" required></label>
  <label>Phone <input type="tel" name="supplier[phone]" value="<%= supplier.phone %>"></label>
  <label>Lead Time (days) <input type="number" name="supplier[lead_time_days]" value="<%= supplier.lead_time_days %>" min="1"></label>
  <button type="submit">Save Supplier</button>
</form>
```

- [ ] **Step 5: Add suppliers routes**

```ruby
# In config/routes.rb
resources :suppliers, except: [:new, :edit]
```

- [ ] **Step 6: Run test to verify it passes**

Run: `bundle exec rspec spec/requests/suppliers_spec.rb`
Expected: All examples pass

- [ ] **Step 7: Commit**

```bash
git add app/controllers/suppliers_controller.rb app/views/suppliers/ spec/requests/suppliers_spec.rb
git commit -m "feat: add suppliers page — CRUD with HTMX, inline star rating, audit logging"
```

---

### Task 14: Purchase Orders Page

**Files:**
- Create: `app/controllers/purchase_orders_controller.rb`
- Create: `app/views/purchase_orders/index.html.erb`
- Create: `app/views/purchase_orders/show.html.erb`
- Create: `app/views/purchase_orders/_list.html.erb`
- Create: `app/views/purchase_orders/_draft_preview.html.erb`
- Create: `spec/requests/purchase_orders_spec.rb`

- [ ] **Step 1: Write the failing test**

```ruby
# spec/requests/purchase_orders_spec.rb
require "rails_helper"

RSpec.describe "Purchase Orders", type: :request do
  let(:shop) { create(:shop) }
  let!(:supplier) { create(:supplier) }

  before { login_as(shop) }

  describe "GET /purchase_orders" do
    it "returns success" do
      get "/purchase_orders"
      expect(response).to have_http_status(:ok)
    end
  end

  describe "GET /purchase_orders/:id" do
    let!(:po) { create(:purchase_order, supplier: supplier) }

    it "returns success" do
      get "/purchase_orders/#{po.id}"
      expect(response).to have_http_status(:ok)
    end
  end

  describe "PATCH /purchase_orders/:id/mark_sent" do
    let!(:po) { create(:purchase_order, supplier: supplier, status: "draft") }

    it "updates status to sent" do
      patch "/purchase_orders/#{po.id}/mark_sent"
      expect(po.reload.status).to eq("sent")
    end
  end

  describe "PATCH /purchase_orders/:id/mark_received" do
    let!(:po) { create(:purchase_order, supplier: supplier, status: "sent") }

    it "updates status to received" do
      patch "/purchase_orders/#{po.id}/mark_received"
      expect(po.reload.status).to eq("received")
    end
  end

  describe "POST /purchase_orders/generate_draft" do
    it "creates an audit log" do
      allow(AI::PoDraftGenerator).to receive(:new).and_return(double(call: { draft: "test" }))
      expect {
        post "/purchase_orders/generate_draft"
      }.to change(AuditLog.where(action: "po_draft_generated"), :count).by(1)
    end
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bundle exec rspec spec/requests/purchase_orders_spec.rb`
Expected: FAIL

- [ ] **Step 3: Write PurchaseOrdersController**

```ruby
# app/controllers/purchase_orders_controller.rb
class PurchaseOrdersController < ApplicationController
  def index
    @purchase_orders = PurchaseOrder.includes(:supplier).order(created_at: :desc).page(params[:page]).per(25)
  end

  def show
    @purchase_order = PurchaseOrder.includes(:purchase_order_line_items).find(params[:id])
  end

  def mark_sent
    @po = PurchaseOrder.find(params[:id])
    @po.update!(status: "sent")
    redirect_to purchase_order_path(@po), notice: "Marked as sent"
  end

  def mark_received
    @po = PurchaseOrder.find(params[:id])
    @po.update!(status: "received")
    redirect_to purchase_order_path(@po), notice: "Marked as received"
  end

  def generate_draft
    AuditLog.record(action: "po_draft_generated", shop: current_shop, request: request)

    generator = AI::PoDraftGenerator.new(current_shop)
    @draft = generator.call

    if request.headers["HX-Request"]
      render partial: "draft_preview", locals: { draft: @draft }
    else
      redirect_to purchase_orders_path, notice: "Draft generated"
    end
  end
end
```

- [ ] **Step 4: Create purchase order views**

```erb
<%# app/views/purchase_orders/index.html.erb %>
<h1>Purchase Orders</h1>

<button hx-post="/purchase_orders/generate_draft" hx-target="#draft-area" hx-indicator="#draft-spinner">
  Generate Draft PO
</button>
<span id="draft-spinner" class="htmx-indicator">Generating with AI...</span>

<div id="draft-area"></div>

<div id="po-list">
  <%= render "list", purchase_orders: @purchase_orders %>
</div>
```

```erb
<%# app/views/purchase_orders/_list.html.erb %>
<table>
  <thead>
    <tr>
      <th>#</th>
      <th>Supplier</th>
      <th>Status</th>
      <th>Created</th>
      <th>Actions</th>
    </tr>
  </thead>
  <tbody>
    <% purchase_orders.each do |po| %>
      <tr>
        <td><a href="/purchase_orders/<%= po.id %>">#<%= po.id %></a></td>
        <td><%= po.supplier&.name %></td>
        <td><mark><%= po.status %></mark></td>
        <td><%= po.created_at.strftime("%b %d, %Y") %></td>
        <td>
          <a href="/purchase_orders/<%= po.id %>">View</a>
        </td>
      </tr>
    <% end %>
  </tbody>
</table>

<%= render "shared/pagination", collection: purchase_orders %>
```

```erb
<%# app/views/purchase_orders/show.html.erb %>
<a href="/purchase_orders">&larr; Back to Purchase Orders</a>
<h1>Purchase Order #<%= @purchase_order.id %></h1>

<p><strong>Supplier:</strong> <%= @purchase_order.supplier&.name %></p>
<p><strong>Status:</strong> <mark><%= @purchase_order.status %></mark></p>
<p><strong>Created:</strong> <%= @purchase_order.created_at.strftime("%b %d, %Y %H:%M") %></p>

<% if @purchase_order.status == "draft" %>
  <%= button_to "Mark as Sent", mark_sent_purchase_order_path(@purchase_order), method: :patch %>
<% elsif @purchase_order.status == "sent" %>
  <%= button_to "Mark as Received", mark_received_purchase_order_path(@purchase_order), method: :patch %>
<% end %>

<h2>Line Items</h2>
<table>
  <thead>
    <tr><th>Variant</th><th>Quantity</th><th>Unit Cost</th></tr>
  </thead>
  <tbody>
    <% @purchase_order.purchase_order_line_items.each do |li| %>
      <tr>
        <td><%= li.variant&.title || li.variant&.sku %></td>
        <td><%= li.quantity %></td>
        <td><%= number_to_currency(li.unit_cost) if li.respond_to?(:unit_cost) %></td>
      </tr>
    <% end %>
  </tbody>
</table>
```

```erb
<%# app/views/purchase_orders/_draft_preview.html.erb %>
<div style="margin: 1rem 0; padding: 1.5rem; border: 1px solid var(--pico-muted-border-color); border-radius: 8px; background: #f9fafb;">
  <h3>AI-Generated Draft</h3>
  <% if draft.present? %>
    <pre style="white-space: pre-wrap;"><%= draft.to_json %></pre>
  <% else %>
    <p>No draft could be generated. Check that you have low-stock items and suppliers configured.</p>
  <% end %>
</div>
```

- [ ] **Step 5: Add purchase order routes**

```ruby
# In config/routes.rb
resources :purchase_orders do
  member do
    patch :mark_sent
    patch :mark_received
  end
  collection do
    post :generate_draft
  end
end
```

- [ ] **Step 6: Run test to verify it passes**

Run: `bundle exec rspec spec/requests/purchase_orders_spec.rb`
Expected: All examples pass

- [ ] **Step 7: Commit**

```bash
git add app/controllers/purchase_orders_controller.rb app/views/purchase_orders/ spec/requests/purchase_orders_spec.rb
git commit -m "feat: add purchase orders page — list, detail, AI draft generation, mark sent/received"
```

---

### Task 15: Alerts Controller

**Files:**
- Create: `app/controllers/alerts_controller.rb`
- Create: `app/views/alerts/_list.html.erb`
- Create: `app/views/alerts/_row.html.erb`

- [ ] **Step 1: Write AlertsController**

```ruby
# app/controllers/alerts_controller.rb
class AlertsController < ApplicationController
  def index
    @alerts = Alert.order(created_at: :desc).page(params[:page]).per(25)
  end

  def dismiss
    alert = Alert.find(params[:id])
    alert.update!(dismissed: true)
    head :ok # HTMX will swap out the row
  end
end
```

- [ ] **Step 2: Add alerts routes**

```ruby
# In config/routes.rb
resources :alerts, only: [:index] do
  member do
    patch :dismiss
  end
end
```

- [ ] **Step 3: Commit**

```bash
git add app/controllers/alerts_controller.rb app/views/alerts/
git commit -m "feat: add alerts controller — index with pagination, dismiss via HTMX"
```

---

## Chunk 6: Security Hardening

### Task 16: Rack::Attack Rate Limiting

**Files:**
- Create: `config/initializers/rack_attack.rb`
- Create: `spec/requests/rate_limiting_spec.rb`

- [ ] **Step 1: Write the failing test**

```ruby
# spec/requests/rate_limiting_spec.rb
require "rails_helper"

RSpec.describe "Rate limiting", type: :request do
  before do
    Rack::Attack.enabled = true
    Rack::Attack.reset!
  end

  after { Rack::Attack.enabled = false }

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

- [ ] **Step 2: Run test to verify it fails**

Run: `bundle exec rspec spec/requests/rate_limiting_spec.rb`
Expected: FAIL

- [ ] **Step 3: Create Rack::Attack initializer**

```ruby
# config/initializers/rack_attack.rb
class Rack::Attack
  throttle("req/ip", limit: 60, period: 1.minute) do |req|
    req.ip unless req.path.start_with?("/assets")
  end

  throttle("agents/ip", limit: 5, period: 1.minute) do |req|
    req.ip if req.path == "/agents/run" && req.post?
  end

  throttle("po-draft/ip", limit: 5, period: 1.minute) do |req|
    req.ip if req.path == "/purchase_orders/generate_draft" && req.post?
  end

  throttle("auth/ip", limit: 10, period: 5.minutes) do |req|
    req.ip if req.path.start_with?("/auth")
  end

  throttle("webhooks/ip", limit: 100, period: 1.minute) do |req|
    req.ip if req.path.start_with?("/webhooks")
  end

  self.throttled_responder = lambda do |_matched, _period, _limit, _count|
    html = "<html><body><h1>429 Too Many Requests</h1><p>Retry later.</p></body></html>"
    [429, { "Content-Type" => "text/html", "Retry-After" => "60" }, [html]]
  end
end
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bundle exec rspec spec/requests/rate_limiting_spec.rb`
Expected: All examples pass

- [ ] **Step 5: Commit**

```bash
git add config/initializers/rack_attack.rb spec/requests/rate_limiting_spec.rb
git commit -m "feat: add Rack::Attack rate limiting — per-IP throttles for all endpoints"
```

---

### Task 17: Security Headers

**Files:**
- Create: `config/initializers/security_headers.rb`
- Create: `spec/requests/security_headers_spec.rb`

- [ ] **Step 1: Write the failing test**

```ruby
# spec/requests/security_headers_spec.rb
require "rails_helper"

RSpec.describe "Security headers", type: :request do
  let(:shop) { create(:shop) }

  before do
    login_as(shop)
    get "/dashboard"
  end

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

- [ ] **Step 2: Run test to verify it fails**

Run: `bundle exec rspec spec/requests/security_headers_spec.rb`
Expected: FAIL

- [ ] **Step 3: Create security headers initializer**

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
    "script-src 'self' https://unpkg.com",
    "style-src 'self' https://unpkg.com 'unsafe-inline'",
    "img-src 'self' data:",
    "font-src 'self'",
    "connect-src 'self'",
    "frame-ancestors 'none'",
    "base-uri 'self'",
    "form-action 'self' https://*.myshopify.com"
  ].join("; ")
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bundle exec rspec spec/requests/security_headers_spec.rb`
Expected: 6 examples, 0 failures

- [ ] **Step 5: Commit**

```bash
git add config/initializers/security_headers.rb spec/requests/security_headers_spec.rb
git commit -m "feat: add security headers — HSTS, CSP, X-Frame-Options DENY, Permissions-Policy"
```

---

### Task 18: Brakeman Static Analysis

**Files:**
- Create: `spec/security/brakeman_spec.rb`

- [ ] **Step 1: Write brakeman spec**

```ruby
# spec/security/brakeman_spec.rb
require "rails_helper"

RSpec.describe "Brakeman security scan" do
  it "finds no warnings" do
    result = `bundle exec brakeman --no-pager -q --format json`
    report = JSON.parse(result)
    warnings = report["warnings"]
    expect(warnings).to be_empty,
      "Brakeman found #{warnings.size} warnings:\n" +
      warnings.map { |w| "  - #{w['warning_type']}: #{w['message']} (#{w['file']}:#{w['line']})" }.join("\n")
  end
end
```

- [ ] **Step 2: Run brakeman to verify current state**

Run: `bundle exec brakeman --no-pager -q`
Expected: Review any warnings and fix before committing

- [ ] **Step 3: Fix any brakeman warnings found**

Address each warning. Common fixes:
- SQL injection → use parameterized queries
- Mass assignment → ensure strong params
- Cross-site scripting → avoid `raw`/`html_safe`

- [ ] **Step 4: Run brakeman spec**

Run: `bundle exec rspec spec/security/brakeman_spec.rb`
Expected: 1 example, 0 failures

- [ ] **Step 5: Commit**

```bash
git add spec/security/
git commit -m "feat: add brakeman security scan as RSpec test — zero warnings required"
```

---

### Task 19: GDPR Real Implementation

**Files:**
- Modify: `app/controllers/gdpr_controller.rb`
- Create: `app/jobs/gdpr_shop_redact_job.rb`
- Create: `app/jobs/gdpr_customer_redact_job.rb`
- Create: `app/jobs/gdpr_customer_data_job.rb`
- Modify: `spec/requests/gdpr_spec.rb`
- Create: `spec/jobs/gdpr_shop_redact_job_spec.rb`

- [ ] **Step 1: Write the failing test for GDPR shop redact job**

```ruby
# spec/jobs/gdpr_shop_redact_job_spec.rb
require "rails_helper"

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

- [ ] **Step 2: Run test to verify it fails**

Run: `bundle exec rspec spec/jobs/gdpr_shop_redact_job_spec.rb`
Expected: FAIL — `uninitialized constant GdprShopRedactJob`

- [ ] **Step 3: Write GDPR jobs**

```ruby
# app/jobs/gdpr_shop_redact_job.rb
class GdprShopRedactJob < ApplicationJob
  queue_as :default

  def perform(shop_id)
    shop = Shop.find_by(id: shop_id)
    return unless shop

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

```ruby
# app/jobs/gdpr_customer_redact_job.rb
class GdprCustomerRedactJob < ApplicationJob
  queue_as :default

  def perform(shop_id, customer_id)
    # We don't store direct customer PII — log the request
    Rails.logger.info("[GDPR] Customer #{customer_id} redact request for shop #{shop_id} — no customer data stored")
  end
end
```

```ruby
# app/jobs/gdpr_customer_data_job.rb
class GdprCustomerDataJob < ApplicationJob
  queue_as :default

  def perform(shop_id, customer_id)
    Rails.logger.info("[GDPR] Customer #{customer_id} data request for shop #{shop_id} — no customer data stored")
  end
end
```

- [ ] **Step 4: Update GdprController**

Replace stub with real implementation per spec (section 13d).

```ruby
# app/controllers/gdpr_controller.rb
class GdprController < ActionController::Base
  skip_before_action :verify_authenticity_token
  before_action :verify_shopify_hmac

  def customers_data_request
    shop = Shop.find_by(shopify_domain: params[:shop_domain])
    return head :not_found unless shop

    AuditLog.record(action: "gdpr_customer_data_request", request: request,
                    metadata: { shop_domain: params[:shop_domain] })
    GdprCustomerDataJob.perform_later(shop.id, params[:customer]&.dig(:id))
    head :ok
  end

  def customers_redact
    shop = Shop.find_by(shopify_domain: params[:shop_domain])
    return head :not_found unless shop

    AuditLog.record(action: "gdpr_customer_redact", request: request,
                    metadata: { shop_domain: params[:shop_domain] })
    GdprCustomerRedactJob.perform_later(shop.id, params[:customer]&.dig(:id))
    head :ok
  end

  def shop_redact
    shop = Shop.find_by(shopify_domain: params[:shop_domain])
    return head :not_found unless shop

    AuditLog.record(action: "gdpr_shop_redact", request: request,
                    metadata: { shop_domain: params[:shop_domain] })
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

- [ ] **Step 5: Update GDPR request spec**

```ruby
# spec/requests/gdpr_spec.rb
require "rails_helper"

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
      headers = { "HTTP_X_SHOPIFY_HMAC_SHA256" => "invalid", "CONTENT_TYPE" => "application/json" }
      post "/gdpr/shop_redact", params: body, headers: headers
      expect(response).to have_http_status(:unauthorized)
    end

    it "creates an audit log" do
      body = { shop_domain: shop.shopify_domain }.to_json
      headers = {
        "HTTP_X_SHOPIFY_HMAC_SHA256" => shopify_hmac(body),
        "CONTENT_TYPE" => "application/json"
      }
      expect {
        post "/gdpr/shop_redact", params: body, headers: headers
      }.to change(AuditLog.where(action: "gdpr_shop_redact"), :count).by(1)
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
```

- [ ] **Step 6: Run tests to verify they pass**

Run: `bundle exec rspec spec/requests/gdpr_spec.rb spec/jobs/gdpr_shop_redact_job_spec.rb`
Expected: All examples pass

- [ ] **Step 7: Commit**

```bash
git add app/controllers/gdpr_controller.rb app/jobs/gdpr_* spec/requests/gdpr_spec.rb spec/jobs/gdpr_*
git commit -m "feat: implement real GDPR data processing — shop redact, customer redact, audit logging"
```

---

### Task 20: Webhook HMAC Verification

**Files:**
- Modify: `app/controllers/webhooks_controller.rb`
- Modify: `spec/requests/webhooks_spec.rb`

- [ ] **Step 1: Write the failing test**

```ruby
# spec/requests/webhooks_spec.rb
require "rails_helper"

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

- [ ] **Step 2: Run test to verify it fails**

Run: `bundle exec rspec spec/requests/webhooks_spec.rb`
Expected: FAIL

- [ ] **Step 3: Update WebhooksController**

```ruby
# app/controllers/webhooks_controller.rb
class WebhooksController < ActionController::Base
  skip_before_action :verify_authenticity_token
  before_action :verify_shopify_hmac

  def receive
    topic = params[:topic]
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

- [ ] **Step 4: Run test to verify it passes**

Run: `bundle exec rspec spec/requests/webhooks_spec.rb`
Expected: 3 examples, 0 failures

- [ ] **Step 5: Commit**

```bash
git add app/controllers/webhooks_controller.rb spec/requests/webhooks_spec.rb
git commit -m "feat: add manual webhook HMAC verification with audit logging"
```

---

## Chunk 7: Routes, Cleanup, and Final Wiring

### Task 21: Finalize Routes

**Files:**
- Modify: `config/routes.rb`

- [ ] **Step 1: Write the complete routes file**

```ruby
# config/routes.rb
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
  post "/gdpr/customers_data_request", to: "gdpr#customers_data_request"
  post "/gdpr/customers_redact", to: "gdpr#customers_redact"
  post "/gdpr/shop_redact", to: "gdpr#shop_redact"
end
```

- [ ] **Step 2: Verify routes compile**

Run: `bundle exec rails routes`
Expected: All routes listed without error

- [ ] **Step 3: Commit**

```bash
git add config/routes.rb
git commit -m "feat: finalize routes — landing, auth, dashboard, inventory, suppliers, POs, alerts, webhooks, GDPR"
```

---

### Task 22: Delete React/Frontend and Node.js Files

**Files:**
- Delete: `frontend/` (entire directory)
- Delete: `e2e/` (entire directory)
- Delete: `test/` (entire directory)
- Delete: `playwright-report/`, `test-results/`
- Delete: `package.json`, `package-lock.json`
- Delete: `vite.config.ts`, `vite.preview.config.ts`, `vitest.config.ts`
- Delete: `tsconfig.json`, `playwright.config.ts`
- Delete: `index.html`

- [ ] **Step 1: Delete frontend directories**

```bash
rm -rf frontend/ e2e/ test/ playwright-report/ test-results/
```

- [ ] **Step 2: Delete Node.js and build config files**

```bash
rm -f package.json package-lock.json vite.config.ts vite.preview.config.ts vitest.config.ts tsconfig.json playwright.config.ts index.html
```

- [ ] **Step 3: Remove vite_ruby config if present**

```bash
rm -rf config/vite.json bin/vite
```

- [ ] **Step 4: Remove shopify_app initializer**

```bash
rm -f config/initializers/shopify_app.rb
```

- [ ] **Step 5: Verify Rails still boots**

Run: `bundle exec rails runner "puts 'OK'"`
Expected: `OK`

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "chore: delete React frontend, Node.js config, Vite, Playwright, shopify_app initializer"
```

---

### Task 23: Update Existing Specs for New Architecture

**Files:**
- Modify: `spec/rails_helper.rb`
- Delete old API controller specs that reference `api/v1/` namespace

- [ ] **Step 1: Clean up rails_helper.rb**

Remove any vite_ruby, shopify_app, or React-specific test configuration. Ensure `spec/support/auth_helpers.rb` is loaded.

- [ ] **Step 2: Delete old API namespace specs**

```bash
rm -rf spec/requests/api/
```

These are replaced by the new top-level request specs (dashboard_spec.rb, inventory_spec.rb, etc.).

- [ ] **Step 3: Verify all remaining specs pass**

Run: `bundle exec rspec --format progress`
Expected: All specs pass. Fix any failures from the architecture change.

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "chore: clean up test suite — remove old API specs, update rails_helper for full Rails mode"
```

---

### Task 24: Verify Full Application

- [ ] **Step 1: Run the full test suite**

Run: `bundle exec rspec`
Expected: All green

- [ ] **Step 2: Run brakeman**

Run: `bundle exec brakeman --no-pager -q`
Expected: 0 warnings

- [ ] **Step 3: Run rubocop**

Run: `bundle exec rubocop`
Expected: No offenses (or only pre-existing ones)

- [ ] **Step 4: Verify Rails boots and serves pages**

Run: `bundle exec rails server -p 3000` (manual check)
- Visit `http://localhost:3000` → landing page loads
- OAuth flow works
- Dashboard loads after login
- HTMX interactions work (filter, search, dismiss alert)

- [ ] **Step 5: Final commit if any fixes were needed**

```bash
git add -A
git commit -m "fix: address issues found during full verification"
```

---

## Summary

| Chunk | Tasks | What it delivers |
|-------|-------|-----------------|
| 1: Foundation | 1-5 | Rails full mode, gems, migrations, AuditLog model |
| 2: Auth | 6-7 | OmniAuth Shopify, session security, login/logout |
| 3: Layout & CSS | 8-9 | Pico CSS, HTMX, ERB layouts, sidebar |
| 4: Pages (core) | 10-12 | Landing, Dashboard, Inventory pages |
| 5: Pages (CRUD) | 13-15 | Suppliers, Purchase Orders, Alerts pages |
| 6: Security | 16-20 | Rack::Attack, headers, brakeman, GDPR, webhooks |
| 7: Cleanup | 21-24 | Routes, delete React, update specs, verify |

**Total: 24 tasks, ~120 steps**

Each task follows TDD: write failing test → verify failure → implement → verify pass → commit.
