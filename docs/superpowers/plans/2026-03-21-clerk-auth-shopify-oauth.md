# Clerk Auth + Shopify OAuth Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace cookie-based Shopify OAuth login with Clerk authentication + Shopify OAuth store connection, transforming the app into a standalone SaaS.

**Architecture:** New `users` table with Clerk user IDs owns `shops`. Three-layer auth: `require_clerk_session` → `require_onboarding` → `require_shop_connection`. Shopify OAuth retained only for store connection (not login). Onboarding wizard collects store info and connects Shopify.

**Tech Stack:** Rails 7.2, clerk-sdk-ruby, svix gem, Clerk JS SDK (CDN), PostgreSQL, ERB + HTMX

**Spec:** `docs/superpowers/specs/2026-03-21-clerk-auth-shopify-oauth-design.md`

---

## File Structure

### New Files
- `db/migrate/TIMESTAMP_create_users.rb` — users table migration
- `db/migrate/TIMESTAMP_add_user_id_to_shops.rb` — shops.user_id FK migration
- `app/models/user.rb` — User model
- `app/controllers/onboarding_controller.rb` — 3-step wizard
- `app/controllers/connections_controller.rb` — Shopify OAuth store connection
- `app/controllers/webhooks/clerk_controller.rb` — Clerk webhook handler
- `app/controllers/account_controller.rb` — User account page
- `app/views/onboarding/show.html.erb` — Onboarding wizard view
- `app/views/layouts/onboarding.html.erb` — Standalone onboarding layout (no sidebar)
- `app/views/connections/shopify_connect.html.erb` — Shopify connect form (used in settings too)
- `app/views/shared/_connect_banner.html.erb` — "Connect your store" banner
- `app/assets/stylesheets/onboarding.css` — Onboarding wizard styles
- `app/assets/javascripts/onboarding.js` — Wizard step transitions
- `config/initializers/clerk.rb` — Clerk SDK configuration
- `config/initializers/acts_as_tenant.rb` — allow nil tenant on shop-optional routes
- `app/views/account/show.html.erb` — User account page view
- `lib/tasks/backfill_users.rake` — Rake task to backfill existing shops with users
- `db/migrate/TIMESTAMP_enforce_user_id_on_shops.rb` — Set user_id NOT NULL after backfill
- `app/jobs/user_hard_delete_job.rb` — 30-day grace period hard delete
- `spec/models/user_spec.rb` — User model specs
- `spec/controllers/onboarding_controller_spec.rb` — Onboarding specs
- `spec/controllers/connections_controller_spec.rb` — Connection specs
- `spec/controllers/webhooks/clerk_controller_spec.rb` — Clerk webhook specs

### Modified Files
- `Gemfile` — add `clerk-sdk-ruby`, `svix`; keep `omniauth-shopify-oauth2` for store connection
- `app/models/shop.rb` — add `belongs_to :user`
- `app/controllers/application_controller.rb` — replace auth with Clerk 3-layer system
- `config/routes.rb` — add onboarding, connections, clerk webhook, shop switch routes
- `config/initializers/omniauth.rb` — keep for store connection, update callback URL
- `config/initializers/security_headers.rb` — update CSP, X-Frame-Options for standalone
- `config/initializers/cors.rb` — remove Shopify admin origin (standalone mode)
- `config/initializers/rack_attack.rb` — update rate limit key extraction
- `app/views/layouts/application.html.erb` — add Clerk JS SDK
- `app/views/shared/_sidebar.html.erb` — show user info, shop switcher, Clerk logout
- `app/views/landing/index.html.erb` — add Clerk sign-up/sign-in buttons
- `app/views/layouts/landing.html.erb` — add Clerk JS SDK
- `.env.example` — add Clerk env vars

### Removed Files
- `app/controllers/auth_controller.rb` — replaced by Clerk + ConnectionsController
- `app/views/auth/install.html.erb` — replaced by Clerk sign-up
- `config/initializers/session_store.rb` — Clerk manages sessions

---

## Task 1: Add Clerk and Svix Gems

**Files:**
- Modify: `Gemfile`
- Modify: `.env.example`

- [ ] **Step 1: Add gems to Gemfile**

In `Gemfile`, after `gem 'omniauth-shopify-oauth2'` (line 15), add:

```ruby
gem 'clerk-sdk-ruby', '~> 4.0'
gem 'svix', '~> 1.0'
```

- [ ] **Step 2: Add Clerk env vars to .env.example**

Append to `.env.example`:

```bash
# Clerk Authentication
CLERK_PUBLISHABLE_KEY=pk_test_your_key
CLERK_SECRET_KEY=sk_test_your_key
CLERK_WEBHOOK_SIGNING_SECRET=whsec_your_secret
```

- [ ] **Step 3: Bundle install**

Run: `bundle install`
Expected: Gems install successfully, `Gemfile.lock` updated.

- [ ] **Step 4: Commit**

```bash
git add Gemfile Gemfile.lock .env.example
git commit -m "feat: add clerk-sdk-ruby and svix gems for auth migration"
```

---

## Task 2: Create Users Table Migration

**Files:**
- Create: `db/migrate/TIMESTAMP_create_users.rb`

- [ ] **Step 1: Generate migration**

Run: `bundle exec rails generate migration CreateUsers`

- [ ] **Step 2: Write migration**

```ruby
# frozen_string_literal: true

class CreateUsers < ActiveRecord::Migration[7.2]
  def change
    create_table :users do |t|
      t.string :clerk_user_id, null: false
      t.string :email, null: false
      t.string :name
      t.string :store_name
      t.string :store_category
      t.integer :onboarding_step, default: 1, null: false
      t.datetime :onboarding_completed_at
      t.bigint :active_shop_id
      t.datetime :deleted_at

      t.timestamps
    end

    add_index :users, :clerk_user_id, unique: true
    add_index :users, :email
    add_index :users, :deleted_at
    # FK for active_shop_id is deferred — added after shops migration via:
    # add_foreign_key :users, :shops, column: :active_shop_id
  end
end
```

Note: The FK from `users.active_shop_id` to `shops.id` cannot be added in this migration because the `shops` table doesn't have `user_id` yet. It will be added in the next migration (Task 3).

- [ ] **Step 3: Run migration**

Run: `bundle exec rails db:migrate`
Expected: Migration runs, `schema.rb` updated with `users` table.

- [ ] **Step 4: Commit**

```bash
git add db/migrate/*_create_users.rb db/schema.rb
git commit -m "feat: create users table for Clerk auth"
```

- [ ] **Step 3: Run migration**

Run: `bundle exec rails db:migrate`
Expected: Migration runs, `schema.rb` updated with `users` table.

- [ ] **Step 4: Commit**

```bash
git add db/migrate/*_create_users.rb db/schema.rb
git commit -m "feat: create users table for Clerk auth"
```

---

## Task 3: Add user_id to Shops Migration

**Files:**
- Create: `db/migrate/TIMESTAMP_add_user_id_to_shops.rb`

- [ ] **Step 1: Generate migration**

Run: `bundle exec rails generate migration AddUserIdToShops`

- [ ] **Step 2: Write migration**

```ruby
# frozen_string_literal: true

class AddUserIdToShops < ActiveRecord::Migration[7.2]
  def change
    add_reference :shops, :user, foreign_key: true, null: true
    add_index :shops, [:user_id, :shop_domain], unique: true
    # Deferred FK from users.active_shop_id → shops.id (created in previous migration)
    add_foreign_key :users, :shops, column: :active_shop_id
  end
end
```

Note: `user_id` is nullable initially. After backfilling existing data, a follow-up migration can set NOT NULL.

- [ ] **Step 3: Run migration**

Run: `bundle exec rails db:migrate`
Expected: `shops` table has `user_id` column with FK and unique index.

- [ ] **Step 4: Commit**

```bash
git add db/migrate/*_add_user_id_to_shops.rb db/schema.rb
git commit -m "feat: add user_id FK to shops table"
```

---

## Task 4: Create User Model

**Files:**
- Create: `app/models/user.rb`
- Create: `spec/models/user_spec.rb`
- Modify: `app/models/shop.rb`

- [ ] **Step 1: Write User model spec**

```ruby
# frozen_string_literal: true

require 'rails_helper'

RSpec.describe User, type: :model do
  describe 'associations' do
    it { is_expected.to have_many(:shops).dependent(:nullify) }
    it { is_expected.to belong_to(:active_shop).class_name('Shop').optional }
  end

  describe 'validations' do
    subject { build(:user) }

    it { is_expected.to validate_presence_of(:clerk_user_id) }
    it { is_expected.to validate_uniqueness_of(:clerk_user_id) }
    it { is_expected.to validate_presence_of(:email) }
    it { is_expected.to allow_value('test@example.com').for(:email) }
    it { is_expected.to_not allow_value('not-an-email').for(:email) }
    it { is_expected.to validate_inclusion_of(:onboarding_step).in_range(1..4) }
  end

  describe 'scopes' do
    it 'active excludes soft-deleted users' do
      active = create(:user)
      create(:user, deleted_at: Time.current)
      expect(User.active).to eq([active])
    end
  end

  describe '#onboarding_completed?' do
    it 'returns false when onboarding_completed_at is nil' do
      user = build(:user, onboarding_completed_at: nil)
      expect(user.onboarding_completed?).to be false
    end

    it 'returns true when onboarding_completed_at is set' do
      user = build(:user, onboarding_completed_at: Time.current)
      expect(user.onboarding_completed?).to be true
    end
  end
end
```

- [ ] **Step 2: Create User factory**

Add to `spec/factories/users.rb`:

```ruby
# frozen_string_literal: true

FactoryBot.define do
  factory :user do
    sequence(:clerk_user_id) { |n| "user_clerk_#{n}" }
    sequence(:email) { |n| "user#{n}@example.com" }
    name { 'Test User' }
    onboarding_step { 1 }

    trait :onboarded do
      onboarding_step { 4 }
      onboarding_completed_at { Time.current }
      store_name { 'Test Store' }
      store_category { 'apparel' }
    end

    trait :with_shop do
      onboarded
      after(:create) do |user|
        shop = create(:shop, user: user)
        user.update!(active_shop_id: shop.id)
      end
    end
  end
end
```

- [ ] **Step 3: Run spec to verify it fails**

Run: `bundle exec rspec spec/models/user_spec.rb`
Expected: FAIL — `User` class not defined yet.

- [ ] **Step 4: Write User model**

Create `app/models/user.rb`:

```ruby
# frozen_string_literal: true

# A SaaS user authenticated via Clerk. Owns one or more Shopify stores.
class User < ApplicationRecord
  has_many :shops, dependent: :nullify
  belongs_to :active_shop, class_name: 'Shop', optional: true

  STORE_CATEGORIES = %w[apparel home electronics other].freeze

  validates :clerk_user_id, presence: true, uniqueness: true
  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :onboarding_step, inclusion: { in: 1..4 }
  validates :store_category, inclusion: { in: STORE_CATEGORIES }, allow_nil: true

  scope :active, -> { where(deleted_at: nil) }

  def onboarding_completed?
    onboarding_completed_at.present?
  end
end
```

- [ ] **Step 5: Update Shop model**

In `app/models/shop.rb`, add after `encrypts :access_token` (line 5):

```ruby
  belongs_to :user, optional: true
```

Also update the existing shop factory in `spec/factories/shops.rb` — add `user { nil }` or `association :user` depending on existing factory structure. Since `user_id` is nullable for now, `nil` is fine.

- [ ] **Step 6: Run specs**

Run: `bundle exec rspec spec/models/user_spec.rb`
Expected: All tests PASS.

- [ ] **Step 7: Commit**

```bash
git add app/models/user.rb app/models/shop.rb spec/models/user_spec.rb spec/factories/users.rb
git commit -m "feat: add User model with Clerk auth fields and validations"
```

---

## Task 5: Configure Clerk SDK

**Files:**
- Create: `config/initializers/clerk.rb`
- Modify: `config/initializers/security_headers.rb`
- Modify: `config/initializers/cors.rb`

- [ ] **Step 1: Create Clerk initializer**

Create `config/initializers/clerk.rb`:

```ruby
# frozen_string_literal: true

Clerk.configure do |config|
  config.api_key = ENV.fetch('CLERK_SECRET_KEY', '')
end
```

- [ ] **Step 2: Create acts_as_tenant initializer**

Create `config/initializers/acts_as_tenant.rb`:

```ruby
# frozen_string_literal: true

# Allow nil tenant on shop-optional routes (onboarding, account, connections).
# Controllers that require a shop enforce it via require_shop_connection.
ActsAsTenant.configure do |config|
  config.require_tenant = false
end
```

- [ ] **Step 3: Update security headers for standalone mode**

In `config/initializers/security_headers.rb`, replace the entire file:

```ruby
# frozen_string_literal: true

Rails.application.config.action_dispatch.default_headers = {
  'Strict-Transport-Security' => 'max-age=31536000; includeSubDomains',
  'X-Content-Type-Options' => 'nosniff',
  'X-Frame-Options' => 'DENY',
  'Referrer-Policy' => 'strict-origin-when-cross-origin',
  'Permissions-Policy' => 'camera=(), microphone=(), geolocation=()',
  'Content-Security-Policy' => [
    "default-src 'self'",
    "script-src 'self' https://unpkg.com https://cdn.jsdelivr.net https://*.clerk.accounts.dev",
    "style-src 'self' https://unpkg.com https://fonts.googleapis.com 'unsafe-inline'",
    "img-src 'self' data: https://cdn.shopify.com https://img.clerk.com",
    "font-src 'self' https://fonts.gstatic.com",
    "connect-src 'self' https://*.clerk.accounts.dev",
    "frame-ancestors 'none'",
    "base-uri 'self'",
    "form-action *"
  ].join('; ')
}
```

Key changes:
- `X-Frame-Options` → `DENY` (no longer embedded in Shopify)
- `frame-ancestors` → `'none'`
- `script-src` → added `*.clerk.accounts.dev`
- `connect-src` → added `*.clerk.accounts.dev`
- `img-src` → added `img.clerk.com` (Clerk avatars)

- [ ] **Step 3: Update CORS**

In `config/initializers/cors.rb`, replace contents:

```ruby
# frozen_string_literal: true

# Standalone SaaS — no longer embedded in Shopify Admin.
# Only allow requests from our own app domain.
Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins ENV.fetch('SHOPIFY_APP_URL', 'https://localhost:3000')
    resource '*',
             headers: :any,
             methods: %i[get post put patch delete options head],
             credentials: true
  end
end
```

Note: `admin.shopify.com` removed — app is no longer embedded. No Clerk domain needed — Clerk JS SDK makes requests to Clerk's servers directly.

- [ ] **Step 4: Commit**

```bash
git add config/initializers/clerk.rb config/initializers/acts_as_tenant.rb config/initializers/security_headers.rb config/initializers/cors.rb
git commit -m "feat: configure Clerk SDK, acts_as_tenant, CSP, and CORS for standalone"
```

---

## Task 6: Rewrite ApplicationController Auth

**Files:**
- Modify: `app/controllers/application_controller.rb`

- [ ] **Step 1: Replace ApplicationController**

Replace `app/controllers/application_controller.rb` entirely:

```ruby
# frozen_string_literal: true

# Base controller providing Clerk authentication, tenant scoping, and cache helpers.
class ApplicationController < ActionController::Base
  before_action :require_clerk_session
  before_action :require_onboarding
  before_action :require_shop_connection
  before_action :set_tenant

  private

  # Layer 1: Clerk session validation
  def require_clerk_session
    return if current_user

    redirect_to root_path, alert: 'Please sign in'
  end

  # Layer 2: Onboarding completion check
  def require_onboarding
    return unless current_user
    return if current_user.onboarding_completed?

    redirect_to onboarding_step_path(step: current_user.onboarding_step)
  end

  # Layer 3: Shop connection check (non-blocking — sets banner flag)
  def require_shop_connection
    return unless current_user&.onboarding_completed?
    return if current_shop.present?

    @show_connect_banner = true
  end

  def current_user
    return @current_user if defined?(@current_user)

    clerk_user_id = clerk_session_user_id
    @current_user = clerk_user_id ? User.active.find_by(clerk_user_id: clerk_user_id) : nil
  end
  helper_method :current_user

  def current_shop
    @current_shop ||= current_user&.active_shop
  end
  helper_method :current_shop

  def set_tenant
    ActsAsTenant.current_tenant = current_shop
  end

  def shop_cache
    @shop_cache ||= Cache::ShopCache.new(current_shop) if current_shop
  end

  # Extract Clerk user ID from session token.
  # clerk-sdk-ruby sets request.env['clerk'] with session claims.
  # Falls back to session-stored ID for dev_login in development.
  def clerk_session_user_id
    request.env.dig('clerk', 'user_id') ||
      request.env.dig('clerk', 'sub') ||
      (Rails.env.development? && session[:dev_clerk_user_id])
  end
end
```

- [ ] **Step 2: Run existing specs to see what breaks**

Run: `bundle exec rspec spec/controllers/ spec/requests/`
Expected: Many failures — existing specs use `session[:shop_id]`. This is expected; we'll update specs in later tasks.

- [ ] **Step 3: Commit**

```bash
git add app/controllers/application_controller.rb
git commit -m "feat: replace cookie auth with Clerk 3-layer auth in ApplicationController"
```

---

## Task 7: Update Routes

**Files:**
- Modify: `config/routes.rb`

- [ ] **Step 1: Update routes**

Replace `config/routes.rb`:

```ruby
# frozen_string_literal: true

Rails.application.routes.draw do
  root 'landing#index'

  # Clerk handles sign-in/sign-up via JS SDK — no server routes needed for login

  # Onboarding wizard
  get '/onboarding', to: 'onboarding#index', as: :onboarding
  get '/onboarding/step/:step', to: 'onboarding#show', as: :onboarding_step
  post '/onboarding/step/:step', to: 'onboarding#update'

  # Shopify store connection (OAuth)
  post '/connections/shopify', to: 'connections#shopify_connect', as: :shopify_connect
  get '/auth/shopify/callback', to: 'connections#shopify_callback'
  get '/auth/failure', to: 'connections#failure'
  delete '/connections/shopify/:id', to: 'connections#shopify_disconnect', as: :shopify_disconnect

  # Shop switching
  patch '/shops/:id/switch', to: 'shops#switch', as: :switch_shop

  # User account
  get '/account', to: 'account#show'
  delete '/logout', to: 'account#destroy'

  # Health check (unauthenticated)
  get '/health', to: 'health#show'

  # Vision / Blog (public)
  get '/vision', to: 'vision#index'

  # App
  get '/dashboard', to: 'dashboard#index'
  post '/agents/run', to: 'dashboard#run_agent'

  resources :inventory, only: %i[index show]
  resources :suppliers, except: %i[new edit]
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

  # Settings
  get '/settings', to: 'settings#show'
  patch '/settings', to: 'settings#update'

  # Clerk webhooks (must be before Shopify catch-all to avoid route conflict)
  post '/webhooks/clerk', to: 'webhooks/clerk#receive'

  # Shopify webhooks (catch-all — must come after specific webhook routes)
  post '/webhooks/:topic', to: 'webhooks#receive'

  # GDPR (required by Shopify)
  post '/gdpr/customers_data_request', to: 'gdpr#customers_data_request'
  post '/gdpr/customers_redact', to: 'gdpr#customers_redact'
  post '/gdpr/shop_redact', to: 'gdpr#shop_redact'

  # Dev-only auto-login (bypasses auth for local viewing)
  get '/dev/login', to: 'account#dev_login' if Rails.env.development?
end
```

- [ ] **Step 2: Commit**

```bash
git add config/routes.rb
git commit -m "feat: add onboarding, connections, clerk webhook, and shop switch routes"
```

---

## Task 8: Create OnboardingController

**Files:**
- Create: `app/controllers/onboarding_controller.rb`
- Create: `app/views/layouts/onboarding.html.erb`
- Create: `app/views/onboarding/show.html.erb`
- Create: `app/assets/stylesheets/onboarding.css`
- Create: `app/assets/javascripts/onboarding.js`

- [ ] **Step 1: Create OnboardingController**

```ruby
# frozen_string_literal: true

# Three-step onboarding wizard for new users.
class OnboardingController < ApplicationController
  skip_before_action :require_onboarding
  skip_before_action :require_shop_connection
  layout 'onboarding'

  before_action :redirect_if_completed

  def index
    redirect_to onboarding_step_path(step: current_user.onboarding_step)
  end

  def show
    @step = params[:step].to_i
    redirect_to onboarding_step_path(step: current_user.onboarding_step) unless valid_step?(@step)
  end

  def update
    @step = params[:step].to_i
    case @step
    when 1 then process_step_1
    when 2 then process_step_2
    when 3 then process_step_3
    else redirect_to onboarding_path
    end
  end

  private

  def redirect_if_completed
    redirect_to '/dashboard' if current_user&.onboarding_completed?
  end

  def valid_step?(step)
    step >= 1 && step <= 3 && step <= current_user.onboarding_step
  end

  def process_step_1
    permitted = params.permit(:store_name, :store_category)
    current_user.update!(
      store_name: permitted[:store_name],
      store_category: permitted[:store_category],
      onboarding_step: 2
    )
    redirect_to onboarding_step_path(step: 2)
  end

  def process_step_2
    if params.permit(:skip)[:skip]
      current_user.update!(onboarding_step: 3)
      redirect_to onboarding_step_path(step: 3)
    else
      permitted = params.permit(:shop_domain)
      shop_domain = permitted[:shop_domain].to_s.strip.downcase
      # Initiate Shopify OAuth — POST to OmniAuth with shop param
      session[:onboarding_return] = true
      session[:connecting_shop] = "#{shop_domain}.myshopify.com"
      redirect_to '/auth/shopify', allow_other_host: true,
                  params: { shop: "#{shop_domain}.myshopify.com" }
    end
  end

  def process_step_3
    permitted = params.permit(:threshold, channels: [])
    threshold = permitted[:threshold].to_i.clamp(1, 999)
    channels = Array(permitted[:channels]).select { |c| %w[in_app email].include?(c) }

    # Store default alert preferences — will be applied when shop connects
    current_user.update!(
      onboarding_step: 4,
      onboarding_completed_at: Time.current
    )

    # Apply settings to active shop if connected
    if current_shop
      current_shop.update_setting('low_stock_threshold', threshold)
      current_shop.update_setting('alert_channels', channels)
    end

    redirect_to '/dashboard'
  end
end
```

- [ ] **Step 2: Create onboarding layout**

Create `app/views/layouts/onboarding.html.erb`:

```erb
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>StockPilot — Setup</title>
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
  <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700;800&display=swap" rel="stylesheet">
  <%= stylesheet_link_tag "onboarding" %>
  <%= csrf_meta_tags %>
</head>
<body>
  <div class="progress-track">
    <div class="progress-fill" style="width: <%= (@step.to_i / 3.0 * 100).round %>%"></div>
  </div>
  <div class="top-bar">
    <div class="logo">stockpilot <span>/ setup</span></div>
    <div class="step-count"><%= @step %> of 3</div>
  </div>
  <%= yield %>
</body>
</html>
```

- [ ] **Step 3: Create onboarding view**

Create `app/views/onboarding/show.html.erb`:

```erb
<div class="onboarding-page">
  <div class="onboarding-content">
    <% case @step %>
    <% when 1 %>
      <%= render 'onboarding/step_1' %>
    <% when 2 %>
      <%= render 'onboarding/step_2' %>
    <% when 3 %>
      <%= render 'onboarding/step_3' %>
    <% end %>
  </div>
</div>
```

- [ ] **Step 4: Create step partials**

Create `app/views/onboarding/_step_1.html.erb`:

```erb
<div class="step-icon">
  <svg viewBox="0 0 24 24" width="32" height="32" fill="none" stroke="#1A1A1A" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round">
    <path d="M3 9l9-7 9 7v11a2 2 0 01-2 2H5a2 2 0 01-2-2V9z"/><polyline points="9 22 9 12 15 12 15 22"/>
  </svg>
</div>
<h1>First, what's your<br>store called?</h1>
<p class="subtitle">We'll use this to set up your workspace.</p>

<%= form_tag onboarding_step_path(step: 1), method: :post do %>
  <div class="input-wrap">
    <label for="store_name">Store name</label>
    <%= text_field_tag :store_name, current_user.store_name, placeholder: "Bean's Boutique", class: 'input-field' %>
  </div>

  <div class="input-wrap">
    <label>What do you sell? <span class="hint">(optional — helps our AI)</span></label>
    <div class="select-grid">
      <% [
        { value: 'apparel', icon: 'tshirt', label: 'Apparel', desc: 'Clothing & accessories' },
        { value: 'home', icon: 'sofa', label: 'Home', desc: 'Furniture & decor' },
        { value: 'electronics', icon: 'laptop', label: 'Electronics', desc: 'Gadgets & devices' },
        { value: 'other', icon: 'package', label: 'Other', desc: 'Something different' }
      ].each do |cat| %>
        <label class="select-card <%= 'selected' if current_user.store_category == cat[:value] %>">
          <%= radio_button_tag :store_category, cat[:value], current_user.store_category == cat[:value], class: 'sr-only' %>
          <div class="card-icon"><%= render "onboarding/icons/#{cat[:icon]}" %></div>
          <h3><%= cat[:label] %></h3>
          <p><%= cat[:desc] %></p>
        </label>
      <% end %>
    </div>
  </div>

  <%= submit_tag 'Continue', class: 'btn btn-primary' %>
<% end %>
```

Create `app/views/onboarding/_step_2.html.erb`:

```erb
<div class="step-icon">
  <svg viewBox="0 0 24 24" width="32" height="32" fill="none" stroke="#1A1A1A" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round">
    <path d="M10 13a5 5 0 007.54.54l3-3a5 5 0 00-7.07-7.07l-1.72 1.71"/>
    <path d="M14 11a5 5 0 00-7.54-.54l-3 3a5 5 0 007.07 7.07l1.71-1.71"/>
  </svg>
</div>
<h1>Now let's connect<br>your Shopify store</h1>
<p class="subtitle">We'll pull in your products, stock levels, and order history. Nothing is modified — read-only access.</p>

<%= form_tag onboarding_step_path(step: 2), method: :post do %>
  <div class="input-wrap">
    <label for="shop_domain">Shopify store URL</label>
    <div class="url-group">
      <%= text_field_tag :shop_domain, nil, placeholder: 'your-store', class: 'input-field' %>
      <div class="domain">.myshopify.com</div>
    </div>
  </div>

  <%= submit_tag 'Connect to Shopify', class: 'btn btn-primary' %>
<% end %>

<%= form_tag onboarding_step_path(step: 2), method: :post, class: 'skip-form' do %>
  <%= hidden_field_tag :skip, true %>
  <%= submit_tag "I'll do this later", class: 'btn btn-ghost' %>
<% end %>

<div class="trust-bar">
  <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="#6D7175" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round">
    <rect x="3" y="11" width="18" height="11" rx="2" ry="2"/><path d="M7 11V7a5 5 0 0110 0v4"/>
  </svg>
  <span>Read-only access · products, inventory, orders, customers · revoke anytime</span>
</div>
```

Create `app/views/onboarding/_step_3.html.erb`:

```erb
<div class="step-icon">
  <svg viewBox="0 0 24 24" width="32" height="32" fill="none" stroke="#1A1A1A" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round">
    <path d="M18 8A6 6 0 006 8c0 7-3 9-3 9h18s-3-2-3-9"/><path d="M13.73 21a2 2 0 01-3.46 0"/>
  </svg>
</div>
<h1>When should we<br>give you a heads up?</h1>
<p class="subtitle">We'll watch your stock and notify you before things run out. Customize per-product later.</p>

<%= form_tag onboarding_step_path(step: 3), method: :post do %>
  <div class="input-wrap">
    <label>Low-stock threshold</label>
    <div class="threshold-control">
      <button type="button" class="threshold-btn" onclick="adjustThreshold(-5)">−</button>
      <%= number_field_tag :threshold, 10, min: 1, max: 999, class: 'threshold-value', id: 'thresholdVal' %>
      <button type="button" class="threshold-btn" onclick="adjustThreshold(5)">+</button>
      <span class="threshold-label">units remaining</span>
    </div>
    <p class="threshold-hint">Most stores use 10–25 depending on how fast items sell</p>
  </div>

  <div class="input-wrap">
    <label>How should we reach you?</label>
    <div class="select-list">
      <label class="select-row selected" data-channel="in_app">
        <%= check_box_tag 'channels[]', 'in_app', true, class: 'sr-only' %>
        <div class="row-logo">
          <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="#1A1A1A" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"><path d="M18 8A6 6 0 006 8c0 7-3 9-3 9h18s-3-2-3-9"/><path d="M13.73 21a2 2 0 01-3.46 0"/></svg>
        </div>
        <div class="row-text">
          <h3>In-app notifications</h3>
          <p>See alerts on your dashboard</p>
        </div>
        <div class="row-check"></div>
      </label>
      <label class="select-row" data-channel="email">
        <%= check_box_tag 'channels[]', 'email', false, class: 'sr-only' %>
        <div class="row-logo">
          <svg width="24" height="24" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><path d="M1.636 6.21v12.152c0 .904.733 1.638 1.636 1.638h1.637V8.486L12 13.714l7.09-5.228V20h1.637c.904 0 1.637-.734 1.637-1.636V6.21c0-1.125-1.283-1.77-2.185-1.098L12 11.077 3.821 5.113C2.92 4.44 1.636 5.086 1.636 6.21z" fill="#EA4335"/><path d="M1.636 6.21v12.152c0 .904.733 1.638 1.636 1.638h1.637V8.486L12 13.714" fill="#4285F4"/><path d="M12 13.714l7.09-5.228V20h1.637c.904 0 1.637-.734 1.637-1.636V6.21c0-1.125-1.283-1.77-2.185-1.098L12 13.714" fill="#34A853"/><path d="M1.636 6.21c0-1.125 1.284-1.77 2.185-1.098L12 11.077" fill="#FBBC05"/><path d="M12 11.077l8.179-5.964c.902-.672 2.185-.027 2.185 1.098" fill="#EA4335"/></svg>
        </div>
        <div class="row-text">
          <h3>Email digests</h3>
          <p>Daily summary of low-stock items</p>
        </div>
        <div class="row-check"></div>
      </label>
      <div class="select-row disabled">
        <div class="row-logo">
          <svg width="24" height="24" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><path d="M5.042 15.165a2.528 2.528 0 01-2.52 2.523A2.528 2.528 0 010 15.165a2.527 2.527 0 012.522-2.52h2.52v2.52zm1.268 0a2.527 2.527 0 012.521-2.52 2.527 2.527 0 012.521 2.52v6.313A2.528 2.528 0 018.831 24a2.528 2.528 0 01-2.52-2.522v-6.313z" fill="#E01E5A"/><path d="M8.831 5.042a2.528 2.528 0 01-2.52-2.52A2.528 2.528 0 018.83 0a2.528 2.528 0 012.521 2.522v2.52H8.831zm0 1.268a2.528 2.528 0 012.521 2.521 2.527 2.527 0 01-2.52 2.521H2.522A2.528 2.528 0 010 8.831a2.528 2.528 0 012.522-2.52h6.309z" fill="#36C5F0"/><path d="M18.958 8.831a2.528 2.528 0 012.522-2.52A2.528 2.528 0 0124 8.831a2.528 2.528 0 01-2.52 2.521h-2.522V8.831zm-1.268 0a2.528 2.528 0 01-2.52 2.521 2.527 2.527 0 01-2.522-2.52V2.522A2.527 2.527 0 0115.17 0a2.528 2.528 0 012.52 2.522v6.309z" fill="#2EB67D"/><path d="M15.17 18.958a2.527 2.527 0 012.52 2.522A2.528 2.528 0 0115.17 24a2.527 2.527 0 01-2.522-2.52v-2.522h2.521zm0-1.268a2.527 2.527 0 01-2.522-2.52 2.528 2.528 0 012.521-2.522h6.313A2.527 2.527 0 0124 15.17a2.528 2.528 0 01-2.52 2.52H15.17z" fill="#ECB22E"/></svg>
        </div>
        <div class="row-text">
          <h3>Slack <span class="badge-soon">Coming soon</span></h3>
          <p>Get pinged in your team channel</p>
        </div>
        <div class="row-check"></div>
      </div>
    </div>
  </div>

  <%= submit_tag 'Start using StockPilot', class: 'btn btn-primary' %>
<% end %>

<script>
function adjustThreshold(delta) {
  const input = document.getElementById('thresholdVal');
  let val = parseInt(input.value) || 10;
  input.value = Math.max(1, Math.min(999, val + delta));
}
</script>
```

- [ ] **Step 5: Create icon partials**

Create `app/views/onboarding/icons/_tshirt.html.erb`:
```erb
<svg viewBox="0 0 24 24" width="28" height="28" fill="none" stroke="#1A1A1A" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"><path d="M15.5 2H8.5L4 5.5L6.5 8L9 6V20C9 20.5523 9.44772 21 10 21H14C14.5523 21 15 20.5523 15 20V6L17.5 8L20 5.5L15.5 2Z"/></svg>
```

Create `app/views/onboarding/icons/_sofa.html.erb`:
```erb
<svg viewBox="0 0 24 24" width="28" height="28" fill="none" stroke="#1A1A1A" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"><path d="M20 9V6a2 2 0 00-2-2H6a2 2 0 00-2 2v3"/><path d="M2 11v5a2 2 0 002 2h16a2 2 0 002-2v-5a2 2 0 00-4 0v2H6v-2a2 2 0 00-4 0z"/><path d="M4 18v2"/><path d="M20 18v2"/></svg>
```

Create `app/views/onboarding/icons/_laptop.html.erb`:
```erb
<svg viewBox="0 0 24 24" width="28" height="28" fill="none" stroke="#1A1A1A" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"><path d="M20 16V7a2 2 0 00-2-2H6a2 2 0 00-2 2v9"/><path d="M1 16h22"/><path d="M1 16l1.5 3h19l1.5-3"/></svg>
```

Create `app/views/onboarding/icons/_package.html.erb`:
```erb
<svg viewBox="0 0 24 24" width="28" height="28" fill="none" stroke="#1A1A1A" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"><path d="M21 16V8a2 2 0 00-1-1.73l-7-4a2 2 0 00-2 0l-7 4A2 2 0 003 8v8a2 2 0 001 1.73l7 4a2 2 0 002 0l7-4A2 2 0 0021 16z"/><polyline points="3.27 6.96 12 12.01 20.73 6.96"/><line x1="12" y1="22.08" x2="12" y2="12"/></svg>
```

- [ ] **Step 6: Create onboarding CSS**

Create `app/assets/stylesheets/onboarding.css` — copy the styles from the approved mockup at `.superpowers/brainstorm/7947-1774149607/onboarding-wizard-v6.html`. Extract the `<style>` block contents into this file. The CSS includes all the green accent styles (`--green-500: #22c55e`), card selections, threshold controls, progress bar, and responsive breakpoints.

- [ ] **Step 7: Commit**

```bash
git add app/controllers/onboarding_controller.rb app/views/layouts/onboarding.html.erb app/views/onboarding/ app/assets/stylesheets/onboarding.css
git commit -m "feat: add onboarding wizard with 3-step flow and approved UI design"
```

---

## Task 9: Create ConnectionsController (Shopify OAuth Store Connection)

**Files:**
- Create: `app/controllers/connections_controller.rb`

- [ ] **Step 1: Create controller**

```ruby
# frozen_string_literal: true

# Handles Shopify OAuth for connecting a store to a user account.
class ConnectionsController < ApplicationController
  skip_before_action :require_shop_connection

  def shopify_connect
    shop_domain = "#{params[:shop_domain].strip.downcase}.myshopify.com"
    session[:connecting_shop] = shop_domain
    redirect_to "/auth/shopify?shop=#{shop_domain}", allow_other_host: true
  end

  def shopify_callback
    auth = request.env['omniauth.auth']
    shop = upsert_shop(auth)

    current_user.update!(active_shop_id: shop.id)
    AuditLog.record(action: 'shop_connected', shop: shop, request: request,
                    metadata: { user_id: current_user.id })

    if session.delete(:onboarding_return)
      current_user.update!(onboarding_step: 3)
      redirect_to onboarding_step_path(step: 3)
    else
      redirect_to '/dashboard', notice: 'Shopify store connected!'
    end
  end

  def failure
    AuditLog.record(action: 'shop_connection_failed', request: request,
                    metadata: { reason: params[:message], user_id: current_user&.id })
    redirect_back fallback_location: '/settings', alert: "Connection failed: #{params[:message]}"
  end

  def shopify_disconnect
    shop = current_user.shops.find(params[:id])
    shop.update!(uninstalled_at: Time.current)

    if current_user.active_shop_id == shop.id
      next_shop = current_user.shops.active.where.not(id: shop.id).first
      current_user.update!(active_shop_id: next_shop&.id)
    end

    redirect_to '/settings', notice: 'Store disconnected.'
  end

  private

  def upsert_shop(auth)
    # Check if this shop is already owned by another user
    existing = Shop.find_by(shop_domain: auth.uid)
    if existing && existing.user_id && existing.user_id != current_user.id
      raise ActiveRecord::RecordInvalid, 'This store is already connected to another account'
    end

    shop = Shop.find_or_initialize_by(shop_domain: auth.uid)
    shop.user = current_user
    shop.access_token = auth.credentials.token
    shop.installed_at ||= Time.current
    shop.uninstalled_at = nil
    shop.save!
    shop
  end
end
```

- [ ] **Step 2: Update OmniAuth initializer for store connection**

In `config/initializers/omniauth.rb`, update the callback URL (line 8) to keep it working for connections:

The file can stay mostly as-is since OmniAuth is still handling the Shopify OAuth flow. The callback route in routes.rb already points to `connections#shopify_callback`. No changes needed — OmniAuth routes are based on the provider name, and our routes file already maps `/auth/shopify/callback` to `connections#shopify_callback`.

- [ ] **Step 3: Commit**

```bash
git add app/controllers/connections_controller.rb
git commit -m "feat: add ConnectionsController for Shopify OAuth store connection"
```

---

## Task 10: Create Clerk Webhook Controller

**Files:**
- Create: `app/controllers/webhooks/clerk_controller.rb`

- [ ] **Step 1: Create controller**

```ruby
# frozen_string_literal: true

module Webhooks
  # Handles Clerk webhook events for user lifecycle (create, update, delete).
  class ClerkController < ActionController::Base
    skip_before_action :verify_authenticity_token
    before_action :verify_clerk_webhook

    def receive
      event_type = params[:type]
      data = params[:data]

      case event_type
      when 'user.created'  then handle_user_created(data)
      when 'user.updated'  then handle_user_updated(data)
      when 'user.deleted'  then handle_user_deleted(data)
      else Rails.logger.info("[Clerk Webhook] Unhandled event: #{event_type}")
      end

      head :ok
    end

    private

    def verify_clerk_webhook
      signing_secret = ENV.fetch('CLERK_WEBHOOK_SIGNING_SECRET', '')
      return head :unauthorized if signing_secret.blank?

      payload = request.body.read
      request.body.rewind
      headers = {
        'svix-id' => request.headers['svix-id'],
        'svix-timestamp' => request.headers['svix-timestamp'],
        'svix-signature' => request.headers['svix-signature']
      }

      begin
        wh = Svix::Webhook.new(signing_secret)
        wh.verify(payload, headers)
      rescue Svix::WebhookVerificationError
        AuditLog.record(action: 'clerk_webhook_verification_failed', request: request)
        head :unauthorized
      end
    end

    def handle_user_created(data)
      email = data.dig(:email_addresses, 0, :email_address)
      User.find_or_create_by!(clerk_user_id: data[:id]) do |user|
        user.email = email
        user.name = [data[:first_name], data[:last_name]].compact.join(' ')
      end
    rescue ActiveRecord::RecordNotUnique
      # Race condition: concurrent webhook delivery. Retry with find.
      retry
    end

    def handle_user_updated(data)
      user = User.find_by(clerk_user_id: data[:id])
      return unless user

      email = data.dig(:email_addresses, 0, :email_address)
      user.update!(
        email: email,
        name: [data[:first_name], data[:last_name]].compact.join(' ')
      )
    end

    def handle_user_deleted(data)
      user = User.find_by(clerk_user_id: data[:id])
      return unless user

      user.update!(deleted_at: Time.current)
      AuditLog.record(action: 'user_soft_deleted', metadata: { clerk_user_id: data[:id] })
    end
  end
end
```

- [ ] **Step 2: Commit**

```bash
git add app/controllers/webhooks/clerk_controller.rb
git commit -m "feat: add Clerk webhook controller with Svix signature verification"
```

---

## Task 11: Create AccountController + Shop Switching

**Files:**
- Create: `app/controllers/account_controller.rb`
- Modify: `app/controllers/shops_controller.rb` (if exists) or create

- [ ] **Step 1: Create AccountController**

```ruby
# frozen_string_literal: true

# User account management and logout.
class AccountController < ApplicationController
  skip_before_action :require_shop_connection

  def show
    @shops = current_user.shops.order(:created_at)
  end

  def destroy
    AuditLog.record(action: 'logout', metadata: { user_id: current_user&.id }, request: request)
    reset_session
    redirect_to root_path
  end

  # Development-only: auto-login as the first user
  def dev_login
    return head :not_found unless Rails.env.development?

    user = User.first
    return redirect_to root_path, alert: 'No users. Run: rails db:seed' unless user

    # Store Clerk user ID in session for dev — clerk_session_user_id falls back to this
    session[:dev_clerk_user_id] = user.clerk_user_id
    redirect_to '/dashboard'
  end
end
```

- [ ] **Step 2: Add shop switching to ShopsController**

Create or modify `app/controllers/shops_controller.rb` — add a `switch` action. If the file already exists, just add the method. If not, create:

```ruby
# frozen_string_literal: true

# Handles shop switching for multi-shop users.
# Note: This may need to be merged with existing ShopsController if one exists.
class ShopsController < ApplicationController
  def switch
    shop = current_user.shops.active.find(params[:id])
    current_user.update!(active_shop_id: shop.id)
    redirect_back fallback_location: '/dashboard', notice: "Switched to #{shop.shop_domain}"
  end
end
```

- [ ] **Step 3: Commit**

```bash
git add app/controllers/account_controller.rb app/controllers/shops_controller.rb
git commit -m "feat: add AccountController and shop switching"
```

---

## Task 12: Update Sidebar and Layouts for Clerk

**Files:**
- Modify: `app/views/shared/_sidebar.html.erb`
- Modify: `app/views/layouts/application.html.erb`
- Modify: `app/views/layouts/landing.html.erb`
- Create: `app/views/shared/_connect_banner.html.erb`

- [ ] **Step 1: Update application layout — add Clerk JS**

In `app/views/layouts/application.html.erb`, add Clerk JS SDK in `<head>` before `csrf_meta_tags`:

```erb
  <script
    async crossorigin="anonymous"
    data-clerk-publishable-key="<%= ENV['CLERK_PUBLISHABLE_KEY'] %>"
    src="https://cdn.jsdelivr.net/npm/@clerk/clerk-js@5/dist/clerk.browser.js"
  ></script>
```

- [ ] **Step 2: Update sidebar user section**

In `app/views/shared/_sidebar.html.erb`, find the `.sidebar__footer` / `.sidebar__user` section and replace the user display and logout button:

Replace `current_shop&.shop_domain&.first&.upcase || 'S'` with `current_user&.name&.first&.upcase || 'U'`.

Replace `current_shop&.shop_domain&.split('.')&.first&.titleize || 'Store'` with `current_user&.name || 'User'`.

Replace the logout `button_to "/logout"` form to use Clerk signOut:

```erb
<button onclick="Clerk.signOut().then(() => window.location = '/')" class="sidebar__logout-link">
  Log out
</button>
```

If user has multiple shops, add a shop switcher above the user section showing `current_shop&.shop_domain` with a dropdown of other shops.

- [ ] **Step 3: Create connect banner partial**

Create `app/views/shared/_connect_banner.html.erb`:

```erb
<% if @show_connect_banner %>
<div class="connect-banner" style="padding: 12px 20px; background: #f0fdf4; border: 1px solid #22c55e; border-radius: 10px; margin-bottom: 16px; display: flex; align-items: center; justify-content: space-between;">
  <span style="font-size: 14px; color: #1A1A1A;">Connect your Shopify store to unlock all features</span>
  <a href="/settings" style="color: #16a34a; font-weight: 600; font-size: 14px; text-decoration: none;">Connect now →</a>
</div>
<% end %>
```

Add `<%= render "shared/connect_banner" %>` in `app/views/layouts/application.html.erb` right after `<%= render "shared/flash" %>`.

- [ ] **Step 4: Update landing layout — add Clerk JS**

In `app/views/layouts/landing.html.erb`, add Clerk JS SDK in `<head>`:

```erb
  <script
    async crossorigin="anonymous"
    data-clerk-publishable-key="<%= ENV['CLERK_PUBLISHABLE_KEY'] %>"
    src="https://cdn.jsdelivr.net/npm/@clerk/clerk-js@5/dist/clerk.browser.js"
  ></script>
```

- [ ] **Step 5: Commit**

```bash
git add app/views/shared/_sidebar.html.erb app/views/layouts/application.html.erb app/views/layouts/landing.html.erb app/views/shared/_connect_banner.html.erb
git commit -m "feat: update layouts and sidebar for Clerk auth + connect banner"
```

---

## Task 13: Update Landing Page with Clerk Sign-in/Sign-up

**Files:**
- Modify: `app/views/landing/index.html.erb`

- [ ] **Step 1: Add Clerk sign-in/sign-up buttons to landing page**

Find the current "Get Started" button/CTA in the landing page and replace it with two buttons:

```erb
<div id="clerk-auth-buttons" style="display: flex; gap: 12px; margin-top: 24px;">
  <button onclick="Clerk.openSignUp()" class="btn btn-primary" style="padding: 14px 32px; background: #22c55e; color: #fff; border: none; border-radius: 12px; font-size: 15px; font-weight: 600; cursor: pointer;">
    Get Started Free
  </button>
  <button onclick="Clerk.openSignIn()" class="btn btn-secondary" style="padding: 14px 32px; background: #fff; color: #1A1A1A; border: 1.5px solid #E1E3E5; border-radius: 12px; font-size: 15px; font-weight: 600; cursor: pointer;">
    Log In
  </button>
</div>
<script>
  // After Clerk loads, redirect authenticated users to dashboard
  window.addEventListener('load', async () => {
    await Clerk.load();
    if (Clerk.user) {
      window.location = '/dashboard';
    }
  });
</script>
```

- [ ] **Step 2: Commit**

```bash
git add app/views/landing/index.html.erb
git commit -m "feat: add Clerk sign-in/sign-up to landing page"
```

---

## Task 14: Remove Old Auth Files

**Files:**
- Remove: `app/controllers/auth_controller.rb`
- Remove: `app/views/auth/install.html.erb`
- Remove: `config/initializers/session_store.rb`

- [ ] **Step 1: Delete old auth controller**

Run: `rm app/controllers/auth_controller.rb`

- [ ] **Step 2: Delete install view**

Run: `rm -rf app/views/auth/`

- [ ] **Step 3: Delete session store config**

Run: `rm config/initializers/session_store.rb`

Note: Rails still uses sessions (for CSRF, flash messages, onboarding_return flag) — it just falls back to the default cookie store. Clerk handles auth sessions separately.

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "chore: remove old cookie-based auth controller and session config"
```

---

## Task 15: Update Rack::Attack for Clerk

**Files:**
- Modify: `config/initializers/rack_attack.rb`

- [ ] **Step 1: Update rate limit key extraction**

In `config/initializers/rack_attack.rb`, replace the `SHOP_OR_IP` lambda:

```ruby
SHOP_OR_IP = lambda do |req|
  # Try Clerk user ID from session, then shop_id, then fall back to IP
  req.env.dig('clerk', 'user_id') ||
    req.env['rack.session']&.dig('shop_id') ||
    req.ip
end
```

Also update the auth throttle path from `/auth` to match Clerk's paths:

```ruby
throttle('auth/ip', limit: 10, period: 5.minutes) do |req|
  req.ip if req.path.start_with?('/auth') || req.path.start_with?('/connections')
end
```

- [ ] **Step 2: Commit**

```bash
git add config/initializers/rack_attack.rb
git commit -m "feat: update rack-attack rate limiting for Clerk auth"
```

---

## Task 16: Update Seeds and Dev Login

**Files:**
- Modify: `db/seeds.rb`

- [ ] **Step 1: Update seeds to create User + Shop**

In `db/seeds.rb`, ensure a User is created alongside the demo shop:

```ruby
user = User.find_or_create_by!(clerk_user_id: 'dev_user_001') do |u|
  u.email = 'dev@stockpilot.com'
  u.name = 'Dev User'
  u.store_name = 'Demo Store'
  u.store_category = 'apparel'
  u.onboarding_step = 4
  u.onboarding_completed_at = Time.current
end

shop = Shop.find_or_create_by!(shop_domain: 'demo-store.myshopify.com') do |s|
  s.access_token = 'dev-token'
  s.user = user
end

user.update!(active_shop_id: shop.id) unless user.active_shop_id
```

- [ ] **Step 2: Run seeds**

Run: `bundle exec rails db:seed`

- [ ] **Step 3: Commit**

```bash
git add db/seeds.rb
git commit -m "feat: update seeds to create User record for dev environment"
```

---

## Task 17: Update Existing Specs

**Files:**
- Modify: `spec/rails_helper.rb` or `spec/support/`
- Modify: Various controller/request specs

- [ ] **Step 1: Add Clerk session helper for specs**

Create `spec/support/clerk_session_helper.rb`:

```ruby
# frozen_string_literal: true

module ClerkSessionHelper
  def sign_in_as(user)
    # Simulate Clerk session by setting the request env
    allow_any_instance_of(ApplicationController).to receive(:clerk_session_user_id)
      .and_return(user.clerk_user_id)
  end

  def sign_in_with_shop(user: nil, shop: nil)
    user ||= create(:user, :with_shop)
    shop ||= user.active_shop
    sign_in_as(user)
    [user, shop]
  end
end

RSpec.configure do |config|
  config.include ClerkSessionHelper, type: :controller
  config.include ClerkSessionHelper, type: :request
end
```

- [ ] **Step 2: Update existing specs that use session[:shop_id]**

Search for `session[:shop_id]` in specs and replace with `sign_in_with_shop`. For example, in request specs:

Before:
```ruby
post '/auth/shopify/callback', ...
# or
allow(controller).to receive(:current_shop).and_return(shop)
```

After:
```ruby
user, shop = sign_in_with_shop
```

- [ ] **Step 3: Run full test suite**

Run: `bundle exec rspec`
Fix any remaining failures from the auth migration.

- [ ] **Step 4: Commit**

```bash
git add spec/
git commit -m "test: update specs for Clerk auth migration"
```

---

## Task 18: Add TECHNICAL_DECISIONS.md Entry

**Files:**
- Modify: `TECHNICAL_DECISIONS.md`

- [ ] **Step 1: Add decision entry**

Append to `TECHNICAL_DECISIONS.md`:

```markdown
## TD-XXX: Clerk for Authentication over Devise/Auth0

**Date:** 2026-03-21
**Decision:** Use Clerk (clerk-sdk-ruby) for user authentication instead of Devise, Auth0, or rolling our own.
**Why:** Clerk provides production-grade auth (email+password, Google OAuth, MFA) with minimal code. The Ruby SDK integrates with Rails middleware for session validation. The free tier covers 10K MAU which is sufficient for launch. Moving from embedded Shopify app to standalone SaaS requires our own auth system — Clerk lets us ship in days instead of weeks.
**Trade-off:** Adds a SaaS dependency (~$25/mo after free tier). If Clerk has downtime, users can't log in. Mitigated by the fact that Clerk has 99.99% uptime SLA and we can migrate to Devise later if needed since our User model is decoupled from Clerk internals (only stores clerk_user_id).
```

- [ ] **Step 2: Commit**

```bash
git add TECHNICAL_DECISIONS.md
git commit -m "docs: add TD entry for Clerk auth decision"
```

---

## Task 19: Backfill Existing Shops with Users

**Files:**
- Create: `lib/tasks/backfill_users.rake`

- [ ] **Step 1: Create backfill Rake task**

```ruby
# frozen_string_literal: true

namespace :data do
  desc 'Create User records for existing Shop records without a user_id'
  task backfill_users: :environment do
    Shop.where(user_id: nil).find_each do |shop|
      user = User.create!(
        clerk_user_id: "migrated_#{shop.id}",
        email: "migrated+#{shop.shop_domain.split('.').first}@stockpilot.com",
        name: shop.shop_domain.split('.').first.titleize,
        store_name: shop.shop_domain.split('.').first.titleize,
        onboarding_step: 4,
        onboarding_completed_at: shop.installed_at || Time.current
      )
      shop.update!(user_id: user.id)
      user.update!(active_shop_id: shop.id)
      puts "Created user #{user.id} for shop #{shop.shop_domain}"
    end
  end
end
```

- [ ] **Step 2: Run backfill (if existing data)**

Run: `bundle exec rails data:backfill_users`

- [ ] **Step 3: Commit**

```bash
git add lib/tasks/backfill_users.rake
git commit -m "feat: add rake task to backfill users for existing shops"
```

---

## Task 20: Enforce user_id NOT NULL on Shops

**Files:**
- Create: `db/migrate/TIMESTAMP_enforce_user_id_on_shops.rb`

- [ ] **Step 1: Generate migration**

Run: `bundle exec rails generate migration EnforceUserIdOnShops`

- [ ] **Step 2: Write migration**

```ruby
# frozen_string_literal: true

class EnforceUserIdOnShops < ActiveRecord::Migration[7.2]
  def change
    # Only safe to run after backfill_users rake task
    change_column_null :shops, :user_id, false
  end
end
```

- [ ] **Step 3: Run migration**

Run: `bundle exec rails db:migrate`

- [ ] **Step 4: Commit**

```bash
git add db/migrate/*_enforce_user_id_on_shops.rb db/schema.rb
git commit -m "feat: enforce NOT NULL on shops.user_id after backfill"
```

---

## Task 21: Add User Hard-Delete Cleanup Job

**Files:**
- Create: `app/jobs/user_hard_delete_job.rb`
- Create: `spec/jobs/user_hard_delete_job_spec.rb`

- [ ] **Step 1: Write spec**

```ruby
# frozen_string_literal: true

require 'rails_helper'

RSpec.describe UserHardDeleteJob, type: :job do
  it 'hard-deletes users soft-deleted more than 30 days ago' do
    old = create(:user, deleted_at: 31.days.ago)
    recent = create(:user, deleted_at: 5.days.ago)
    active = create(:user)

    described_class.new.perform

    expect(User.find_by(id: old.id)).to be_nil
    expect(User.find_by(id: recent.id)).to be_present
    expect(User.find_by(id: active.id)).to be_present
  end
end
```

- [ ] **Step 2: Run spec to verify it fails**

Run: `bundle exec rspec spec/jobs/user_hard_delete_job_spec.rb`
Expected: FAIL — class not defined.

- [ ] **Step 3: Write job**

```ruby
# frozen_string_literal: true

# Permanently deletes users that were soft-deleted more than 30 days ago.
# Scheduled via sidekiq-cron to run daily.
class UserHardDeleteJob < ApplicationJob
  queue_as :default

  GRACE_PERIOD = 30.days

  def perform
    User.where.not(deleted_at: nil)
        .where(deleted_at: ...GRACE_PERIOD.ago)
        .find_each do |user|
      user.shops.update_all(user_id: nil) # rubocop:disable Rails/SkipsModelValidations
      user.destroy!
      Rails.logger.info("[UserHardDelete] Permanently deleted user #{user.id}")
    end
  end
end
```

- [ ] **Step 4: Run spec**

Run: `bundle exec rspec spec/jobs/user_hard_delete_job_spec.rb`
Expected: PASS.

- [ ] **Step 5: Add to sidekiq-cron schedule**

In `config/sidekiq.yml` or cron config, add:

```yaml
user_hard_delete:
  cron: '0 3 * * *'  # Daily at 3am
  class: UserHardDeleteJob
```

- [ ] **Step 6: Commit**

```bash
git add app/jobs/user_hard_delete_job.rb spec/jobs/user_hard_delete_job_spec.rb config/sidekiq.yml
git commit -m "feat: add UserHardDeleteJob with 30-day grace period"
```

---

## Task 22: Create Account View

**Files:**
- Create: `app/views/account/show.html.erb`

- [ ] **Step 1: Create view**

```erb
<div class="page-header">
  <h1>Account</h1>
</div>

<div class="card" style="padding: 24px; margin-bottom: 20px;">
  <h2 style="font-size: 16px; font-weight: 600; margin-bottom: 16px;">Profile</h2>
  <div style="display: flex; flex-direction: column; gap: 8px;">
    <div><strong>Name:</strong> <%= current_user.name %></div>
    <div><strong>Email:</strong> <%= current_user.email %></div>
    <div><strong>Store:</strong> <%= current_user.store_name || 'Not set' %></div>
  </div>
</div>

<div class="card" style="padding: 24px;">
  <h2 style="font-size: 16px; font-weight: 600; margin-bottom: 16px;">Connected Stores</h2>
  <% if current_user.shops.any? %>
    <% current_user.shops.each do |shop| %>
      <div style="display: flex; align-items: center; justify-content: space-between; padding: 12px 0; border-bottom: 1px solid #E1E3E5;">
        <div>
          <div style="font-weight: 500;"><%= shop.shop_domain %></div>
          <div style="font-size: 13px; color: #6D7175;">
            <%= shop.uninstalled? ? 'Disconnected' : 'Connected' %>
            <%= ' · Active' if shop.id == current_user.active_shop_id %>
          </div>
        </div>
        <div style="display: flex; gap: 8px;">
          <% unless shop.id == current_user.active_shop_id %>
            <%= button_to 'Switch', switch_shop_path(shop), method: :patch, class: 'btn-sm' %>
          <% end %>
          <%= button_to 'Disconnect', shopify_disconnect_path(shop), method: :delete, class: 'btn-sm btn-destructive',
              data: { confirm: 'Are you sure? Your data will be preserved.' } %>
        </div>
      </div>
    <% end %>
  <% else %>
    <p style="color: #6D7175;">No stores connected. <%= link_to 'Connect a store', '/settings' %>.</p>
  <% end %>
</div>
```

- [ ] **Step 2: Commit**

```bash
git add app/views/account/show.html.erb
git commit -m "feat: add account page with connected stores management"
```

---

## Task 23: Controller Specs for New Controllers

**Files:**
- Create: `spec/requests/onboarding_spec.rb`
- Create: `spec/requests/connections_spec.rb`
- Create: `spec/requests/webhooks/clerk_spec.rb`

- [ ] **Step 1: Write onboarding request spec**

```ruby
# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Onboarding', type: :request do
  let(:user) { create(:user, onboarding_step: 1) }

  before { sign_in_as(user) }

  describe 'GET /onboarding' do
    it 'redirects to current step' do
      get '/onboarding'
      expect(response).to redirect_to('/onboarding/step/1')
    end
  end

  describe 'GET /onboarding/step/1' do
    it 'renders step 1' do
      get '/onboarding/step/1'
      expect(response).to have_http_status(:ok)
    end
  end

  describe 'POST /onboarding/step/1' do
    it 'saves store info and advances to step 2' do
      post '/onboarding/step/1', params: { store_name: 'My Store', store_category: 'apparel' }
      expect(user.reload.store_name).to eq('My Store')
      expect(user.onboarding_step).to eq(2)
      expect(response).to redirect_to('/onboarding/step/2')
    end
  end

  describe 'POST /onboarding/step/2 with skip' do
    before { user.update!(onboarding_step: 2) }

    it 'skips to step 3' do
      post '/onboarding/step/2', params: { skip: true }
      expect(user.reload.onboarding_step).to eq(3)
      expect(response).to redirect_to('/onboarding/step/3')
    end
  end

  describe 'POST /onboarding/step/3' do
    before { user.update!(onboarding_step: 3) }

    it 'completes onboarding and redirects to dashboard' do
      post '/onboarding/step/3', params: { threshold: 15, channels: ['in_app'] }
      expect(user.reload.onboarding_completed?).to be true
      expect(response).to redirect_to('/dashboard')
    end
  end

  describe 'completed user' do
    let(:user) { create(:user, :onboarded) }

    it 'redirects to dashboard' do
      get '/onboarding/step/1'
      expect(response).to redirect_to('/dashboard')
    end
  end
end
```

- [ ] **Step 2: Write Clerk webhook request spec**

```ruby
# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Webhooks::Clerk', type: :request do
  let(:signing_secret) { 'whsec_test_secret' }

  before do
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with('CLERK_WEBHOOK_SIGNING_SECRET', '').and_return(signing_secret)
  end

  describe 'POST /webhooks/clerk' do
    context 'with invalid signature' do
      it 'returns unauthorized' do
        post '/webhooks/clerk', params: { type: 'user.created', data: {} }.to_json,
             headers: { 'Content-Type' => 'application/json' }
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'user.created event' do
      it 'creates a user record (with valid webhook verification mocked)' do
        # Mock Svix verification to skip signature check in test
        allow_any_instance_of(Svix::Webhook).to receive(:verify).and_return(true)

        post '/webhooks/clerk',
             params: {
               type: 'user.created',
               data: {
                 id: 'clerk_123',
                 first_name: 'Test',
                 last_name: 'User',
                 email_addresses: [{ email_address: 'test@example.com' }]
               }
             }.to_json,
             headers: {
               'Content-Type' => 'application/json',
               'svix-id' => 'msg_test',
               'svix-timestamp' => Time.current.to_i.to_s,
               'svix-signature' => 'v1,test'
             }

        expect(response).to have_http_status(:ok)
        expect(User.find_by(clerk_user_id: 'clerk_123')).to be_present
      end
    end

    context 'user.deleted event' do
      it 'soft-deletes the user' do
        user = create(:user, clerk_user_id: 'clerk_456')
        allow_any_instance_of(Svix::Webhook).to receive(:verify).and_return(true)

        post '/webhooks/clerk',
             params: { type: 'user.deleted', data: { id: 'clerk_456' } }.to_json,
             headers: {
               'Content-Type' => 'application/json',
               'svix-id' => 'msg_test',
               'svix-timestamp' => Time.current.to_i.to_s,
               'svix-signature' => 'v1,test'
             }

        expect(response).to have_http_status(:ok)
        expect(user.reload.deleted_at).to be_present
      end
    end
  end
end
```

- [ ] **Step 3: Run all new specs**

Run: `bundle exec rspec spec/requests/onboarding_spec.rb spec/requests/webhooks/clerk_spec.rb`
Expected: All PASS.

- [ ] **Step 4: Commit**

```bash
git add spec/requests/onboarding_spec.rb spec/requests/webhooks/clerk_spec.rb
git commit -m "test: add request specs for onboarding and Clerk webhooks"
```
