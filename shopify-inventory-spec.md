# Shopify Inventory Intelligence App — Full Implementation Spec

> **Stack:** Ruby on Rails 7.2 (API mode) · PostgreSQL 16 · Sidekiq 7 + Redis · React 18 + TypeScript + Shopify Polaris 13 · Vite Ruby · SendGrid · Claude API
>
> **Shopify API version:** `2025-01` (pinned; review quarterly per Shopify's deprecation schedule)

---

## Table of Contents

1. [Project Overview](#1-project-overview)
2. [Architecture](#2-architecture)
3. [Database Schema](#3-database-schema)
4. [Backend — Rails API](#4-backend--rails-api)
5. [Background Jobs](#5-background-jobs)
6. [Frontend — React + Polaris](#6-frontend--react--polaris)
7. [Shopify Integration](#7-shopify-integration)
8. [AI Layer](#8-ai-layer)
9. [Environment & Config](#9-environment--config)
10. [Testing](#10-testing)
11. [Deployment](#11-deployment)
12. [Phased Build Plan](#12-phased-build-plan)

---

## 1. Project Overview

### What It Does
An embedded Shopify app that gives merchants real-time inventory intelligence: low-stock alerts, automated reorder suggestions, manufacturer email drafts, weekly reports, and AI-generated insights.

### V1 Scope (Ship This First)
- Shopify install via `shopify_app` gem + embedded app shell (App Bridge v4)
- Inventory sync via GraphQL Admin API + low-stock dashboard
- Email alerts when stock drops below threshold
- Weekly auto-generated inventory reports (timezone-aware)
- Supplier management + reorder email drafts
- GDPR mandatory webhooks + full webhook HMAC verification

### V2 Additions (After V1)
- AI insights via Claude API
- Customer DNA profiles from order history
- Outgoing webhooks to external tools
- Multi-location inventory support

---

## 2. Architecture

### Monorepo with Vite Ruby

The app ships as a single Rails deployable. The React frontend is compiled by Vite Ruby and served by Rails, eliminating CORS configuration, dual deployments, and cross-origin session headaches.

```
┌──────────────────────────────────────────────────────────────┐
│  Shopify Admin (Merchant's Store)                            │
│  - GraphQL Admin API (Products, Inventory, Orders)           │
│  - Webhooks → your app (HMAC-verified)                       │
│  - App Bridge v4 session tokens (JWT)                        │
└────────────────────┬─────────────────────────────────────────┘
                     │ Session Token JWT + GraphQL API calls
┌────────────────────▼─────────────────────────────────────────┐
│  Rails App (app.yourdomain.com)                              │
│  ┌──────────────┐ ┌──────────────┐ ┌──────────────────────┐  │
│  │ Auth (JWT)   │ │ Inventory    │ │ Notification Service │  │
│  │ shopify_app  │ │ Sync + Rules │ │ Email + Webhooks     │  │
│  │ gem + tokens │ │              │ │                      │  │
│  └──────────────┘ └──────────────┘ └──────────────────────┘  │
│  ┌──────────────┐ ┌──────────────┐ ┌──────────────────────┐  │
│  │ Report Gen   │ │ AI Service   │ │ PO / Supplier Svc    │  │
│  │ Weekly jobs  │ │ Claude API   │ │ Draft + Send emails  │  │
│  └──────────────┘ └──────────────┘ └──────────────────────┘  │
│                                                              │
│  Vite Ruby → serves React + Polaris frontend                 │
└──────────┬──────────────────┬───────────────────────────────┘
           │                  │
    ┌──────▼──────┐    ┌──────▼──────┐
    │ PostgreSQL  │    │  Sidekiq    │
    │ (primary DB)│    │  + Redis    │
    └─────────────┘    └─────────────┘
```

### Directory Structure

```
shopify-inventory/
├── app/
│   ├── controllers/
│   │   ├── concerns/
│   │   │   └── shopify_webhook_verification.rb
│   │   ├── authenticated_controller.rb
│   │   ├── webhooks_controller.rb
│   │   ├── gdpr_controller.rb
│   │   └── api/v1/
│   │       ├── products_controller.rb
│   │       ├── inventory_controller.rb
│   │       ├── alerts_controller.rb
│   │       ├── reports_controller.rb
│   │       ├── suppliers_controller.rb
│   │       ├── purchase_orders_controller.rb
│   │       ├── settings_controller.rb
│   │       ├── shops_controller.rb
│   │       └── health_controller.rb
│   ├── models/
│   │   ├── shop.rb
│   │   ├── product.rb
│   │   ├── variant.rb
│   │   ├── inventory_snapshot.rb
│   │   ├── supplier.rb
│   │   ├── alert.rb
│   │   ├── weekly_report.rb
│   │   ├── purchase_order.rb
│   │   ├── purchase_order_line_item.rb
│   │   └── webhook_endpoint.rb
│   ├── services/
│   │   ├── shopify/
│   │   │   ├── inventory_fetcher.rb
│   │   │   ├── graphql_client.rb
│   │   │   └── webhook_registrar.rb
│   │   ├── inventory/
│   │   │   ├── persister.rb
│   │   │   ├── snapshotter.rb
│   │   │   └── low_stock_detector.rb
│   │   ├── notifications/
│   │   │   └── alert_sender.rb
│   │   ├── reports/
│   │   │   └── weekly_generator.rb
│   │   └── ai/
│   │       ├── insights_generator.rb
│   │       └── po_draft_generator.rb
│   ├── jobs/
│   │   ├── application_job.rb
│   │   ├── inventory_sync_job.rb
│   │   ├── daily_sync_all_shops_job.rb
│   │   ├── weekly_report_job.rb
│   │   ├── weekly_report_all_shops_job.rb
│   │   ├── webhook_delivery_job.rb
│   │   └── snapshot_cleanup_job.rb
│   └── mailers/
│       ├── alert_mailer.rb
│       └── report_mailer.rb
├── frontend/                      # Vite Ruby entrypoint
│   ├── entrypoints/
│   │   └── application.tsx
│   └── src/
│       ├── App.tsx
│       ├── pages/
│       ├── components/
│       ├── hooks/
│       │   └── useAuthenticatedFetch.ts
│       ├── api/
│       └── types/
├── config/
│   ├── routes.rb
│   ├── initializers/
│   │   ├── shopify_app.rb
│   │   └── sidekiq.rb
│   └── vite.json
├── db/
│   └── migrate/
├── Gemfile
├── Dockerfile
├── docker-compose.yml
└── vite.config.ts
```

---

## 3. Database Schema

### `shops`
```sql
CREATE TABLE shops (
  id                BIGSERIAL PRIMARY KEY,
  shop_domain       VARCHAR(255) NOT NULL UNIQUE,
  access_token      VARCHAR(255) NOT NULL,  -- encrypted at application layer (see model)
  plan              VARCHAR(50)  DEFAULT 'free',
  installed_at      TIMESTAMP    NOT NULL DEFAULT NOW(),
  uninstalled_at    TIMESTAMP,
  synced_at         TIMESTAMP,              -- last successful inventory sync
  settings          JSONB        NOT NULL DEFAULT '{}',
  -- settings keys:
  -- low_stock_threshold: integer (default: 10)
  -- alert_email: string
  -- alert_channels: array ['email']
  -- weekly_report_day: string ('monday')
  -- timezone: string ('America/Toronto')
  created_at        TIMESTAMP    NOT NULL DEFAULT NOW(),
  updated_at        TIMESTAMP    NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_shops_domain ON shops(shop_domain);
```

### `products`
```sql
CREATE TABLE products (
  id                 BIGSERIAL PRIMARY KEY,
  shop_id            BIGINT       NOT NULL REFERENCES shops(id) ON DELETE CASCADE,
  shopify_product_id BIGINT       NOT NULL,
  title              VARCHAR(255),
  product_type       VARCHAR(255),
  vendor             VARCHAR(255),
  status             VARCHAR(50),  -- 'active', 'draft', 'archived'
  deleted_at         TIMESTAMP,    -- soft-delete when products/delete webhook fires
  synced_at          TIMESTAMP,
  created_at         TIMESTAMP    NOT NULL DEFAULT NOW(),
  updated_at         TIMESTAMP    NOT NULL DEFAULT NOW(),
  UNIQUE(shop_id, shopify_product_id)
);

CREATE INDEX idx_products_shop_id ON products(shop_id);
CREATE INDEX idx_products_status ON products(shop_id, status);
```

### `variants`
```sql
CREATE TABLE variants (
  id                        BIGSERIAL PRIMARY KEY,
  shop_id                   BIGINT       NOT NULL REFERENCES shops(id) ON DELETE CASCADE,
  product_id                BIGINT       NOT NULL REFERENCES products(id) ON DELETE CASCADE,
  shopify_variant_id        BIGINT       NOT NULL,
  shopify_inventory_item_id BIGINT,
  sku                       VARCHAR(255),
  title                     VARCHAR(255),
  price                     DECIMAL(10, 2),
  supplier_id               BIGINT       REFERENCES suppliers(id) ON DELETE SET NULL,
  low_stock_threshold       INTEGER,     -- overrides shop-level default if set
  created_at                TIMESTAMP    NOT NULL DEFAULT NOW(),
  updated_at                TIMESTAMP    NOT NULL DEFAULT NOW(),
  UNIQUE(shop_id, shopify_variant_id)
);

CREATE INDEX idx_variants_shop_id ON variants(shop_id);
CREATE INDEX idx_variants_product_id ON variants(product_id);
CREATE INDEX idx_variants_supplier_id ON variants(supplier_id);
CREATE INDEX idx_variants_sku ON variants(shop_id, sku);
```

### `inventory_snapshots`
```sql
CREATE TABLE inventory_snapshots (
  id                BIGSERIAL PRIMARY KEY,
  shop_id           BIGINT       NOT NULL REFERENCES shops(id) ON DELETE CASCADE,
  variant_id        BIGINT       NOT NULL REFERENCES variants(id) ON DELETE CASCADE,
  available         INTEGER      NOT NULL DEFAULT 0,
  on_hand           INTEGER      NOT NULL DEFAULT 0,
  committed         INTEGER      NOT NULL DEFAULT 0,
  incoming          INTEGER      NOT NULL DEFAULT 0,
  snapshotted_at    TIMESTAMP    NOT NULL DEFAULT NOW(),
  created_at        TIMESTAMP    NOT NULL DEFAULT NOW()
);

-- Time-series queries: "latest snapshot for variant X"
CREATE INDEX idx_snapshots_variant_time
  ON inventory_snapshots(variant_id, snapshotted_at DESC);

-- Cleanup queries: "snapshots older than 90 days"
CREATE INDEX idx_snapshots_shop_time
  ON inventory_snapshots(shop_id, snapshotted_at);
```

**Retention policy:** Snapshots older than 90 days are deleted nightly by `SnapshotCleanupJob`. For shops needing longer history, daily snapshots older than 90 days are aggregated to weekly averages before deletion (V2).

### `suppliers`
```sql
CREATE TABLE suppliers (
  id                BIGSERIAL PRIMARY KEY,
  shop_id           BIGINT       NOT NULL REFERENCES shops(id) ON DELETE CASCADE,
  name              VARCHAR(255) NOT NULL,
  email             VARCHAR(255),
  contact_name      VARCHAR(255),
  lead_time_days    INTEGER      DEFAULT 7,
  notes             TEXT,
  created_at        TIMESTAMP    NOT NULL DEFAULT NOW(),
  updated_at        TIMESTAMP    NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_suppliers_shop_id ON suppliers(shop_id);
```

### `alerts`
```sql
CREATE TABLE alerts (
  id                BIGSERIAL PRIMARY KEY,
  shop_id           BIGINT       NOT NULL REFERENCES shops(id) ON DELETE CASCADE,
  variant_id        BIGINT       NOT NULL REFERENCES variants(id) ON DELETE CASCADE,
  alert_type        VARCHAR(50)  NOT NULL,  -- 'low_stock', 'out_of_stock'
  channel           VARCHAR(50)  NOT NULL,  -- 'email', 'webhook'
  status            VARCHAR(50)  NOT NULL DEFAULT 'sent',  -- 'sent', 'failed', 'acknowledged'
  triggered_at      TIMESTAMP    NOT NULL DEFAULT NOW(),
  metadata          JSONB        DEFAULT '{}',
  created_at        TIMESTAMP    NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_alerts_shop_id ON alerts(shop_id);
CREATE INDEX idx_alerts_variant_day ON alerts(shop_id, variant_id, triggered_at);
```

### `weekly_reports`
```sql
CREATE TABLE weekly_reports (
  id                BIGSERIAL PRIMARY KEY,
  shop_id           BIGINT       NOT NULL REFERENCES shops(id) ON DELETE CASCADE,
  week_start        DATE         NOT NULL,
  week_end          DATE         NOT NULL,
  payload           JSONB        NOT NULL DEFAULT '{}',
  -- payload structure:
  -- { top_sellers: [], stockouts: [], low_sku_count: int,
  --   reorder_suggestions: [], ai_commentary: string }
  emailed_at        TIMESTAMP,
  created_at        TIMESTAMP    NOT NULL DEFAULT NOW(),
  UNIQUE(shop_id, week_start)
);

CREATE INDEX idx_weekly_reports_shop_id ON weekly_reports(shop_id);
```

### `purchase_orders`
```sql
CREATE TABLE purchase_orders (
  id                BIGSERIAL PRIMARY KEY,
  shop_id           BIGINT       NOT NULL REFERENCES shops(id) ON DELETE CASCADE,
  supplier_id       BIGINT       NOT NULL REFERENCES suppliers(id),
  po_number         VARCHAR(50),
  status            VARCHAR(50)  NOT NULL DEFAULT 'draft',  -- 'draft', 'sent', 'confirmed'
  draft_body        TEXT,
  sent_at           TIMESTAMP,
  created_at        TIMESTAMP    NOT NULL DEFAULT NOW(),
  updated_at        TIMESTAMP    NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_purchase_orders_shop_id ON purchase_orders(shop_id);
CREATE INDEX idx_purchase_orders_supplier_id ON purchase_orders(supplier_id);
```

### `purchase_order_line_items`
```sql
CREATE TABLE purchase_order_line_items (
  id                  BIGSERIAL PRIMARY KEY,
  purchase_order_id   BIGINT       NOT NULL REFERENCES purchase_orders(id) ON DELETE CASCADE,
  variant_id          BIGINT       NOT NULL REFERENCES variants(id),
  sku                 VARCHAR(255),
  title               VARCHAR(255),
  qty_ordered         INTEGER      NOT NULL DEFAULT 0,
  qty_received        INTEGER      NOT NULL DEFAULT 0,
  unit_price          DECIMAL(10, 2),
  created_at          TIMESTAMP    NOT NULL DEFAULT NOW(),
  updated_at          TIMESTAMP    NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_po_line_items_po_id ON purchase_order_line_items(purchase_order_id);
CREATE INDEX idx_po_line_items_variant_id ON purchase_order_line_items(variant_id);
```

### `webhook_endpoints`
```sql
CREATE TABLE webhook_endpoints (
  id                BIGSERIAL PRIMARY KEY,
  shop_id           BIGINT       NOT NULL REFERENCES shops(id) ON DELETE CASCADE,
  url               VARCHAR(500) NOT NULL,
  event_type        VARCHAR(100) NOT NULL,  -- 'low_stock', 'report_ready', 'out_of_stock'
  is_active         BOOLEAN      NOT NULL DEFAULT TRUE,
  last_fired_at     TIMESTAMP,
  last_status_code  INTEGER,
  created_at        TIMESTAMP    NOT NULL DEFAULT NOW(),
  updated_at        TIMESTAMP    NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_webhook_endpoints_shop_id ON webhook_endpoints(shop_id);
```

### `customers` (V2)
```sql
CREATE TABLE customers (
  id                      BIGSERIAL PRIMARY KEY,
  shop_id                 BIGINT       NOT NULL REFERENCES shops(id) ON DELETE CASCADE,
  shopify_customer_id     BIGINT       NOT NULL,
  email                   VARCHAR(255),
  first_name              VARCHAR(255),
  last_name               VARCHAR(255),
  total_orders            INTEGER      DEFAULT 0,
  total_spent             DECIMAL(12, 2) DEFAULT 0,
  avg_order_value         DECIMAL(10, 2),
  avg_days_between_orders DECIMAL(6, 1),
  first_order_at          TIMESTAMP,
  last_order_at           TIMESTAMP,
  top_product_types       JSONB        DEFAULT '[]',
  created_at              TIMESTAMP    NOT NULL DEFAULT NOW(),
  updated_at              TIMESTAMP    NOT NULL DEFAULT NOW(),
  UNIQUE(shop_id, shopify_customer_id)
);

CREATE INDEX idx_customers_shop_id ON customers(shop_id);
```

---

## 4. Backend — Rails API

### Gemfile (key dependencies)

```ruby
# Gemfile
gem "rails", "~> 7.2"
gem "pg"
gem "puma"
gem "sidekiq", "~> 7.0"
gem "sidekiq-cron"
gem "redis"
gem "shopify_app", "~> 22.0"      # handles OAuth, session tokens, webhooks
gem "shopify_api", "~> 14.0"
gem "vite_rails"
gem "httparty"
gem "sendgrid-ruby"
gem "anthropic"                    # Claude API SDK
gem "acts_as_tenant"               # multi-tenant scoping
gem "kaminari"                     # pagination
gem "blueprinter"                  # JSON serialization

group :development, :test do
  gem "rspec-rails"
  gem "factory_bot_rails"
  gem "webmock"
  gem "dotenv-rails"
end
```

### shopify_app Initializer

```ruby
# config/initializers/shopify_app.rb
ShopifyApp.configure do |config|
  config.application_name = "Inventory Intelligence"
  config.old_secret       = ""
  config.scope            = "read_products,read_inventory,read_orders,read_customers"
  config.embedded_app     = true
  config.after_authenticate_job = { job: AfterAuthenticateJob, inline: false }
  config.api_version      = "2025-01"
  config.shop_session_repository = "Shop"

  config.api_key    = ENV.fetch("SHOPIFY_API_KEY")
  config.secret     = ENV.fetch("SHOPIFY_API_SECRET")
  config.host       = ENV.fetch("SHOPIFY_APP_URL")

  # Webhooks registered automatically by shopify_app gem
  config.webhooks = [
    { topic: "app/uninstalled",        address: "api/webhooks/app_uninstalled" },
    { topic: "products/update",        address: "api/webhooks/products_update" },
    { topic: "products/delete",        address: "api/webhooks/products_delete" },
    { topic: "customers/data_request", address: "api/webhooks/customers_data_request" },
    { topic: "customers/redact",       address: "api/webhooks/customers_redact" },
    { topic: "shop/redact",            address: "api/webhooks/shop_redact" },
  ]
end
```

### Routes

```ruby
# config/routes.rb
Rails.application.routes.draw do
  # shopify_app gem mounts OAuth + session token routes automatically
  mount ShopifyApp::Engine, at: "/"

  # Health check (unauthenticated)
  get "/health", to: "health#show"

  # Shopify webhook receivers (HMAC-verified, no session token needed)
  post "/api/webhooks/:topic", to: "webhooks#receive",
       constraints: { topic: /[a-z_]+/ }

  # GDPR mandatory endpoints
  post "/api/webhooks/customers_data_request", to: "gdpr#customers_data_request"
  post "/api/webhooks/customers_redact",       to: "gdpr#customers_redact"
  post "/api/webhooks/shop_redact",            to: "gdpr#shop_redact"

  # Authenticated API endpoints (session token JWT verified)
  namespace :api do
    namespace :v1 do
      # Shop + settings
      resource  :shop,        only: [:show, :update]
      resource  :settings,    only: [:show, :update]

      # Inventory
      resources :products,    only: [:index, :show]
      resources :variants,    only: [:index, :show, :update]
      post "/inventory/sync", to: "inventory#sync"

      # Alerts
      resources :alerts,      only: [:index, :update]

      # Reports
      resources :reports,     only: [:index, :show]
      post "/reports/generate", to: "reports#generate"

      # Suppliers + POs
      resources :suppliers
      resources :purchase_orders do
        member do
          post :send_email
        end
        collection do
          post :generate_draft
        end
      end

      # Webhooks config (merchant's outgoing webhooks)
      resources :webhook_endpoints

      # AI (V2)
      get "/ai/insights", to: "ai#insights"

      # Customers (V2)
      resources :customers, only: [:index, :show]
    end
  end
end
```

### Models

#### `Shop` — encrypted access token + tenant root

```ruby
# app/models/shop.rb
class Shop < ApplicationRecord
  include ShopifyApp::ShopSessionStorageWithScopes

  encrypts :access_token  # Rails 7 encrypted attributes — uses RAILS_MASTER_KEY

  has_many :products, dependent: :destroy
  has_many :variants, dependent: :destroy
  has_many :inventory_snapshots, dependent: :destroy
  has_many :suppliers, dependent: :destroy
  has_many :alerts, dependent: :destroy
  has_many :weekly_reports, dependent: :destroy
  has_many :purchase_orders, dependent: :destroy
  has_many :webhook_endpoints, dependent: :destroy
  has_many :customers, dependent: :destroy

  scope :active, -> { where(uninstalled_at: nil) }

  def timezone
    settings["timezone"] || "America/Toronto"
  end

  def low_stock_threshold
    settings["low_stock_threshold"] || 10
  end

  def alert_email
    settings["alert_email"]
  end
end
```

#### Tenant-scoped models with `acts_as_tenant`

```ruby
# app/models/application_record.rb
class ApplicationRecord < ActiveRecord::Base
  self.abstract_class = true
end

# app/models/product.rb
class Product < ApplicationRecord
  acts_as_tenant :shop

  has_many :variants, dependent: :destroy
  scope :active, -> { where(deleted_at: nil) }
end

# app/models/variant.rb
class Variant < ApplicationRecord
  acts_as_tenant :shop

  belongs_to :product
  belongs_to :supplier, optional: true
  has_many :inventory_snapshots, dependent: :destroy
  has_many :alerts, dependent: :destroy
  has_many :purchase_order_line_items, dependent: :restrict_with_error
end

# app/models/inventory_snapshot.rb
class InventorySnapshot < ApplicationRecord
  acts_as_tenant :shop

  belongs_to :variant
end

# app/models/supplier.rb
class Supplier < ApplicationRecord
  acts_as_tenant :shop

  has_many :variants, dependent: :nullify
  has_many :purchase_orders, dependent: :restrict_with_error
end

# app/models/alert.rb
class Alert < ApplicationRecord
  acts_as_tenant :shop

  belongs_to :variant
end

# app/models/weekly_report.rb
class WeeklyReport < ApplicationRecord
  acts_as_tenant :shop
end

# app/models/purchase_order.rb
class PurchaseOrder < ApplicationRecord
  acts_as_tenant :shop

  belongs_to :supplier
  has_many :line_items, class_name: "PurchaseOrderLineItem", dependent: :destroy
  accepts_nested_attributes_for :line_items
end

# app/models/purchase_order_line_item.rb
class PurchaseOrderLineItem < ApplicationRecord
  belongs_to :purchase_order
  belongs_to :variant
end

# app/models/webhook_endpoint.rb
class WebhookEndpoint < ApplicationRecord
  acts_as_tenant :shop

  scope :active, -> { where(is_active: true) }
end

# app/models/customer.rb  (V2)
class Customer < ApplicationRecord
  acts_as_tenant :shop
end
```

### Controllers

#### Health Check (unauthenticated)

```ruby
# app/controllers/health_controller.rb
class HealthController < ActionController::API
  def show
    ActiveRecord::Base.connection.execute("SELECT 1")
    redis_ok = Redis.new(url: ENV["REDIS_URL"]).ping == "PONG"
    render json: { status: "ok", db: true, redis: redis_ok }, status: :ok
  rescue StandardError => e
    render json: { status: "degraded", error: e.message }, status: :service_unavailable
  end
end
```

#### Authenticated Base Controller (Session Token JWT)

```ruby
# app/controllers/authenticated_controller.rb
class AuthenticatedController < ActionController::API
  include ShopifyApp::EnsureHasSession

  before_action :set_tenant

  private

  # ShopifyApp::EnsureHasSession verifies the App Bridge session token JWT
  # and sets @current_shopify_session with the authenticated shop domain.
  # No X-Shop-Domain header trust. No cookie sessions.

  def set_tenant
    shop_domain = current_shopify_session&.shop
    @current_shop = Shop.active.find_by!(shop_domain: shop_domain)
    ActsAsTenant.current_tenant = @current_shop
  rescue ActiveRecord::RecordNotFound
    render json: { error: "Shop not found or uninstalled" }, status: :unauthorized
  end

  def current_shop
    @current_shop
  end
end
```

#### Webhook Controller (HMAC-verified)

```ruby
# app/controllers/webhooks_controller.rb
class WebhooksController < ActionController::API
  include ShopifyApp::WebhookVerification  # verifies X-Shopify-Hmac-SHA256

  def receive
    topic = params[:topic]
    shop_domain = request.headers["X-Shopify-Shop-Domain"]
    body = request.body.read

    case topic
    when "app_uninstalled"
      handle_app_uninstalled(shop_domain)
    when "products_update"
      handle_products_update(shop_domain, JSON.parse(body))
    when "products_delete"
      handle_products_delete(shop_domain, JSON.parse(body))
    else
      Rails.logger.warn("[Webhook] Unhandled topic: #{topic}")
    end

    head :ok
  end

  private

  def handle_app_uninstalled(shop_domain)
    shop = Shop.find_by(shop_domain: shop_domain)
    shop&.update!(uninstalled_at: Time.current, access_token: "")
  end

  def handle_products_update(shop_domain, data)
    shop = Shop.active.find_by(shop_domain: shop_domain)
    return unless shop

    ActsAsTenant.with_tenant(shop) do
      Inventory::Persister.new(shop).upsert_single_product(data)
    end
  end

  def handle_products_delete(shop_domain, data)
    shop = Shop.active.find_by(shop_domain: shop_domain)
    return unless shop

    ActsAsTenant.with_tenant(shop) do
      product = Product.find_by(shopify_product_id: data["id"])
      product&.update!(deleted_at: Time.current)
    end
  end
end
```

#### GDPR Controller (mandatory for Shopify app review)

```ruby
# app/controllers/gdpr_controller.rb
class GdprController < ActionController::API
  include ShopifyApp::WebhookVerification

  # Shopify sends this when a customer requests their data.
  # This app stores no direct customer PII in V1 — acknowledge the request.
  def customers_data_request
    payload = JSON.parse(request.body.read)
    Rails.logger.info("[GDPR] customers/data_request for shop #{payload['shop_domain']}")
    # V2: if customers table has data, compile and email it to the merchant
    head :ok
  end

  # Shopify sends this when a customer requests deletion of their data.
  def customers_redact
    payload = JSON.parse(request.body.read)
    shop = Shop.find_by(shop_domain: payload["shop_domain"])
    if shop
      customer_id = payload.dig("customer", "id")
      ActsAsTenant.with_tenant(shop) do
        Customer.where(shopify_customer_id: customer_id).destroy_all
      end
    end
    head :ok
  end

  # Shopify sends this 48 hours after a shop uninstalls. Delete all shop data.
  def shop_redact
    payload = JSON.parse(request.body.read)
    shop = Shop.find_by(shop_domain: payload["shop_domain"])
    shop&.destroy!  # cascades via dependent: :destroy on all associations
    head :ok
  end
end
```

#### Inventory Controller

```ruby
# app/controllers/api/v1/inventory_controller.rb
module Api
  module V1
    class InventoryController < AuthenticatedController
      def sync
        job = InventorySyncJob.perform_later(current_shop.id)
        render json: { status: "queued", job_id: job.job_id }
      end
    end
  end
end
```

#### Products Controller (with pagination)

```ruby
# app/controllers/api/v1/products_controller.rb
module Api
  module V1
    class ProductsController < AuthenticatedController
      def index
        products = current_shop.products
                                .active
                                .includes(:variants)
                                .order(:title)

        if params[:filter] == "low_stock"
          products = products.joins(:variants)
                             .where(variants: { id: low_stock_variant_ids })
                             .distinct
        end

        products = products.page(params[:page]).per(params[:per_page] || 25)

        render json: {
          products: ProductBlueprint.render_as_hash(products),
          meta: pagination_meta(products)
        }
      end

      def show
        product = current_shop.products.active.find(params[:id])
        render json: ProductBlueprint.render_as_hash(product, view: :detail)
      end

      private

      def low_stock_variant_ids
        # Subquery: get the latest snapshot per variant, then filter by threshold
        latest_snapshots = InventorySnapshot
          .select("DISTINCT ON (variant_id) variant_id, available")
          .where(shop_id: current_shop.id)
          .order(:variant_id, snapshotted_at: :desc)

        Variant.where(shop_id: current_shop.id)
               .joins("INNER JOIN (#{latest_snapshots.to_sql}) ls ON ls.variant_id = variants.id")
               .where("ls.available < COALESCE(variants.low_stock_threshold, ?)", current_shop.low_stock_threshold)
               .select(:id)
      end

      def pagination_meta(collection)
        {
          current_page: collection.current_page,
          total_pages: collection.total_pages,
          total_count: collection.total_count,
          per_page: collection.limit_value
        }
      end
    end
  end
end
```

### Services

#### `Shopify::GraphqlClient` — unified GraphQL with rate limit handling

```ruby
# app/services/shopify/graphql_client.rb
module Shopify
  class GraphqlClient
    MAX_RETRIES = 3
    THROTTLE_SLEEP = 2.0  # seconds

    class ShopifyThrottledError < StandardError; end
    class ShopifyApiError < StandardError; end

    def initialize(shop)
      @shop = shop
      @client = ShopifyAPI::Clients::Graphql::Admin.new(
        session: build_session
      )
    end

    def query(graphql_query, variables: {})
      retries = 0
      begin
        response = @client.query(query: graphql_query, variables: variables)

        if response.body.dig("errors")
          errors = response.body["errors"]
          throttled = errors.any? { |e| e.dig("extensions", "code") == "THROTTLED" }
          if throttled
            raise ShopifyThrottledError, "Rate limited by Shopify"
          else
            raise ShopifyApiError, errors.map { |e| e["message"] }.join(", ")
          end
        end

        response.body["data"]
      rescue ShopifyThrottledError => e
        retries += 1
        if retries <= MAX_RETRIES
          sleep(THROTTLE_SLEEP * retries)
          retry
        end
        raise e
      end
    end

    # Paginate through a GraphQL connection, yielding each page of nodes.
    # Returns all nodes concatenated.
    def paginate(graphql_query, variables: {}, connection_path:)
      all_nodes = []
      cursor = nil

      loop do
        data = query(graphql_query, variables: variables.merge(cursor: cursor))
        connection = data.dig(*connection_path)
        break unless connection

        all_nodes.concat(connection["nodes"] || connection["edges"]&.map { |e| e["node"] } || [])

        page_info = connection["pageInfo"]
        break unless page_info&.dig("hasNextPage")
        cursor = page_info["endCursor"]
      end

      all_nodes
    end

    private

    def build_session
      ShopifyAPI::Auth::Session.new(
        shop: @shop.shop_domain,
        access_token: @shop.access_token  # decrypted automatically by Rails
      )
    end
  end
end
```

#### `Shopify::InventoryFetcher` — all GraphQL, no REST

```ruby
# app/services/shopify/inventory_fetcher.rb
module Shopify
  class InventoryFetcher
    PRODUCTS_QUERY = <<~GQL
      query($cursor: String) {
        products(first: 50, after: $cursor) {
          pageInfo { hasNextPage endCursor }
          nodes {
            id
            legacyResourceId
            title
            productType
            vendor
            status
            variants(first: 100) {
              nodes {
                id
                legacyResourceId
                sku
                title
                price
                inventoryItem {
                  id
                  legacyResourceId
                  inventoryLevels(first: 10) {
                    nodes {
                      id
                      quantities(names: ["available", "on_hand", "committed", "incoming"]) {
                        name
                        quantity
                      }
                      location {
                        id
                        name
                      }
                    }
                  }
                }
              }
            }
          }
        }
      }
    GQL

    def initialize(shop)
      @shop = shop
      @client = GraphqlClient.new(shop)
    end

    def call
      products = @client.paginate(
        PRODUCTS_QUERY,
        connection_path: ["products"]
      )

      {
        products: products,
        fetched_at: Time.current
      }
    end
  end
end
```

#### `Shopify::WebhookRegistrar`

```ruby
# app/services/shopify/webhook_registrar.rb
module Shopify
  class WebhookRegistrar
    def self.call(shop)
      # shopify_app gem handles webhook registration automatically
      # via config.webhooks in the initializer. This service exists
      # for manual re-registration if needed.
      session = ShopifyAPI::Auth::Session.new(
        shop: shop.shop_domain,
        access_token: shop.access_token
      )

      ShopifyApp.configuration.webhooks.each do |webhook_config|
        ShopifyAPI::Webhooks::Registry.register(
          topic: webhook_config[:topic],
          session: session,
          path: webhook_config[:address]
        )
      end
    end
  end
end
```

#### `Inventory::Persister` — upsert products + variants

```ruby
# app/services/inventory/persister.rb
module Inventory
  class Persister
    def initialize(shop)
      @shop = shop
    end

    def upsert(data)
      ActsAsTenant.with_tenant(@shop) do
        data[:products].each do |product_data|
          upsert_single_product_from_graphql(product_data)
        end
      end
    end

    def upsert_single_product(shopify_data)
      # Called from products/update webhook (REST format)
      product = Product.find_or_initialize_by(
        shopify_product_id: shopify_data["id"]
      )
      product.update!(
        title: shopify_data["title"],
        product_type: shopify_data["product_type"],
        vendor: shopify_data["vendor"],
        status: shopify_data["status"],
        synced_at: Time.current
      )

      (shopify_data["variants"] || []).each do |v_data|
        variant = Variant.find_or_initialize_by(
          shopify_variant_id: v_data["id"]
        )
        variant.update!(
          product: product,
          sku: v_data["sku"],
          title: v_data["title"],
          price: v_data["price"],
          shopify_inventory_item_id: v_data["inventory_item_id"]
        )
      end
    end

    private

    def upsert_single_product_from_graphql(product_node)
      product = Product.find_or_initialize_by(
        shopify_product_id: product_node["legacyResourceId"].to_i
      )
      product.update!(
        title: product_node["title"],
        product_type: product_node["productType"],
        vendor: product_node["vendor"],
        status: product_node["status"]&.downcase,
        deleted_at: nil,
        synced_at: Time.current
      )

      (product_node.dig("variants", "nodes") || []).each do |v_node|
        variant = Variant.find_or_initialize_by(
          shopify_variant_id: v_node["legacyResourceId"].to_i
        )
        variant.update!(
          product: product,
          sku: v_node["sku"],
          title: v_node["title"],
          price: v_node["price"]&.to_d,
          shopify_inventory_item_id: v_node.dig("inventoryItem", "legacyResourceId")&.to_i
        )
      end

      product
    end
  end
end
```

#### `Inventory::Snapshotter` — extract levels from GraphQL response

```ruby
# app/services/inventory/snapshotter.rb
module Inventory
  class Snapshotter
    def initialize(shop)
      @shop = shop
    end

    def snapshot(products_data)
      now = Time.current
      rows = []

      products_data.each do |product_node|
        (product_node.dig("variants", "nodes") || []).each do |v_node|
          variant = Variant.find_by(
            shop_id: @shop.id,
            shopify_variant_id: v_node["legacyResourceId"].to_i
          )
          next unless variant

          levels = v_node.dig("inventoryItem", "inventoryLevels", "nodes") || []
          # Aggregate across locations (V1 treats all locations as one)
          totals = aggregate_levels(levels)

          rows << {
            shop_id: @shop.id,
            variant_id: variant.id,
            available: totals[:available],
            on_hand: totals[:on_hand],
            committed: totals[:committed],
            incoming: totals[:incoming],
            snapshotted_at: now,
            created_at: now
          }
        end
      end

      # Bulk insert for efficiency
      InventorySnapshot.insert_all(rows) if rows.any?
    end

    private

    def aggregate_levels(level_nodes)
      totals = { available: 0, on_hand: 0, committed: 0, incoming: 0 }

      level_nodes.each do |level|
        (level["quantities"] || []).each do |q|
          key = q["name"].to_sym
          totals[key] = (totals[key] || 0) + (q["quantity"] || 0) if totals.key?(key)
        end
      end

      totals
    end
  end
end
```

#### `Inventory::LowStockDetector` — efficient subquery, no N+1

```ruby
# app/services/inventory/low_stock_detector.rb
module Inventory
  class LowStockDetector
    def initialize(shop)
      @shop = shop
    end

    def detect
      # Use DISTINCT ON to get the latest snapshot per variant in one query.
      # This avoids N+1: we don't load all snapshots per variant.
      latest_snapshots_sql = InventorySnapshot
        .where(shop_id: @shop.id)
        .select("DISTINCT ON (variant_id) variant_id, available, on_hand, committed, incoming, snapshotted_at")
        .order(:variant_id, snapshotted_at: :desc)
        .to_sql

      results = Variant
        .where(shop_id: @shop.id)
        .joins("INNER JOIN (#{latest_snapshots_sql}) latest ON latest.variant_id = variants.id")
        .joins(:product)
        .where(products: { deleted_at: nil })
        .select(
          "variants.*",
          "latest.available AS latest_available",
          "latest.on_hand AS latest_on_hand",
          "latest.committed AS latest_committed",
          "latest.incoming AS latest_incoming",
          "latest.snapshotted_at AS latest_snapshotted_at"
        )

      results.map do |variant|
        threshold = variant.low_stock_threshold || @shop.low_stock_threshold
        available = variant.latest_available.to_i

        status = if available <= 0
                   :out_of_stock
                 elsif available < threshold
                   :low_stock
                 else
                   :ok
                 end

        {
          variant: variant,
          available: available,
          on_hand: variant.latest_on_hand.to_i,
          status: status,
          threshold: threshold
        }
      end
    end
  end
end
```

#### `Notifications::AlertSender`

```ruby
# app/services/notifications/alert_sender.rb
module Notifications
  class AlertSender
    def initialize(shop)
      @shop = shop
    end

    def send_low_stock_alerts(flagged_variants)
      new_alerts = flagged_variants.select { |v| not_already_alerted?(v[:variant]) }
      return if new_alerts.empty?

      email = @shop.alert_email
      if email.present?
        AlertMailer.low_stock(shop: @shop, variants: new_alerts, to: email).deliver_later
      end

      fire_webhooks("low_stock", new_alerts)

      new_alerts.each do |item|
        Alert.create!(
          shop: @shop,
          variant: item[:variant],
          alert_type: item[:status].to_s,
          channel: email.present? ? "email" : "webhook",
          status: "sent"
        )
      end
    end

    private

    def not_already_alerted?(variant)
      !Alert.where(shop: @shop, variant: variant)
            .where(triggered_at: Time.current.beginning_of_day..)
            .exists?
    end

    def fire_webhooks(event_type, data)
      @shop.webhook_endpoints
           .active
           .where(event_type: event_type)
           .find_each do |endpoint|
        WebhookDeliveryJob.perform_later(
          endpoint.id,
          data.map { |item|
            {
              variant_id: item[:variant].id,
              sku: item[:variant].sku,
              status: item[:status],
              available: item[:available],
              threshold: item[:threshold]
            }
          }
        )
      end
    end
  end
end
```

#### `Reports::WeeklyGenerator`

```ruby
# app/services/reports/weekly_generator.rb
module Reports
  class WeeklyGenerator
    def initialize(shop, week_start)
      @shop = shop
      @week_start = week_start
      @week_end = week_start + 6.days
    end

    def generate
      {
        top_sellers: top_sellers,
        stockouts: stockouts_this_week,
        low_sku_count: low_stock_count,
        reorder_suggestions: reorder_suggestions
      }
    end

    private

    def top_sellers
      # Variants that had the largest inventory decrease over the week
      snapshots_start = InventorySnapshot
        .where(shop_id: @shop.id)
        .where(snapshotted_at: @week_start.beginning_of_day..@week_start.end_of_day)
        .select("DISTINCT ON (variant_id) variant_id, available")
        .order(:variant_id, :snapshotted_at)

      snapshots_end = InventorySnapshot
        .where(shop_id: @shop.id)
        .where(snapshotted_at: @week_end.beginning_of_day..@week_end.end_of_day)
        .select("DISTINCT ON (variant_id) variant_id, available")
        .order(:variant_id, snapshotted_at: :desc)

      Variant
        .where(shop_id: @shop.id)
        .joins("INNER JOIN (#{snapshots_start.to_sql}) snap_start ON snap_start.variant_id = variants.id")
        .joins("INNER JOIN (#{snapshots_end.to_sql}) snap_end ON snap_end.variant_id = variants.id")
        .select("variants.id, variants.sku, variants.title, " \
                "(snap_start.available - snap_end.available) AS units_sold")
        .order("units_sold DESC")
        .limit(10)
        .map { |v| { id: v.id, sku: v.sku, title: v.title, units_sold: v.units_sold.to_i } }
    end

    def stockouts_this_week
      Alert.where(shop_id: @shop.id, alert_type: "out_of_stock")
           .where(triggered_at: @week_start.beginning_of_day..@week_end.end_of_day)
           .includes(variant: :product)
           .map { |a| { sku: a.variant.sku, product: a.variant.product.title } }
    end

    def low_stock_count
      Inventory::LowStockDetector.new(@shop).detect.count { |v| v[:status] != :ok }
    end

    def reorder_suggestions
      Inventory::LowStockDetector.new(@shop).detect
        .select { |v| v[:status] != :ok }
        .select { |v| v[:variant].supplier_id.present? }
        .group_by { |v| v[:variant].supplier_id }
        .map do |supplier_id, items|
          supplier = Supplier.find(supplier_id)
          {
            supplier: { id: supplier.id, name: supplier.name },
            items: items.map { |i|
              {
                variant_id: i[:variant].id,
                sku: i[:variant].sku,
                title: i[:variant].title,
                available: i[:available],
                suggested_qty: [i[:threshold] * 2 - i[:available], 0].max
              }
            }
          }
        end
    end
  end
end
```

---

## 5. Background Jobs

### `ApplicationJob` — portable retry with error handling

```ruby
# app/jobs/application_job.rb
class ApplicationJob < ActiveJob::Base
  # Use ActiveJob's retry_on for portability across queue backends.
  # Works with Sidekiq, GoodJob, Solid Queue, etc.
  retry_on StandardError, wait: :polynomially_longer, attempts: 3

  # Discard if the shop was uninstalled while the job was queued
  discard_on ActiveRecord::RecordNotFound

  around_perform do |job, block|
    Rails.logger.tagged(self.class.name, job.job_id) do
      block.call
    end
  end
end
```

### `InventorySyncJob`

```ruby
# app/jobs/inventory_sync_job.rb
class InventorySyncJob < ApplicationJob
  queue_as :default

  # Shopify API errors get exponential backoff
  retry_on Shopify::GraphqlClient::ShopifyThrottledError,
           wait: :polynomially_longer, attempts: 5
  retry_on Shopify::GraphqlClient::ShopifyApiError,
           wait: 30.seconds, attempts: 3

  def perform(shop_id)
    shop = Shop.find(shop_id)

    ActsAsTenant.with_tenant(shop) do
      # 1. Fetch from Shopify (all GraphQL)
      data = Shopify::InventoryFetcher.new(shop).call

      # 2. Upsert products + variants
      Inventory::Persister.new(shop).upsert(data)

      # 3. Snapshot inventory levels
      Inventory::Snapshotter.new(shop).snapshot(data[:products])

      # 4. Check low stock + alert
      flagged = Inventory::LowStockDetector.new(shop).detect
                                           .reject { |v| v[:status] == :ok }
      Notifications::AlertSender.new(shop).send_low_stock_alerts(flagged)
    end

    shop.update!(synced_at: Time.current)
  end
end
```

### `DailySyncAllShopsJob`

```ruby
# app/jobs/daily_sync_all_shops_job.rb
class DailySyncAllShopsJob < ApplicationJob
  queue_as :default

  def perform
    Shop.active.find_each do |shop|
      InventorySyncJob.perform_later(shop.id)
    end
  end
end
```

### `WeeklyReportJob`

```ruby
# app/jobs/weekly_report_job.rb
class WeeklyReportJob < ApplicationJob
  queue_as :reports

  retry_on Net::SMTPError, wait: 5.minutes, attempts: 3

  def perform(shop_id)
    shop = Shop.find(shop_id)
    week_start = Date.current.beginning_of_week

    report_data = ActsAsTenant.with_tenant(shop) do
      Reports::WeeklyGenerator.new(shop, week_start).generate
    end

    report = WeeklyReport.find_or_initialize_by(
      shop: shop,
      week_start: week_start
    )
    report.update!(
      week_end: week_start + 6.days,
      payload: report_data
    )

    email = shop.alert_email
    if email.present?
      ReportMailer.weekly_summary(report: report, to: email).deliver_later
      report.update!(emailed_at: Time.current)
    end
  end
end
```

### `WeeklyReportAllShopsJob` — timezone-aware scheduling

```ruby
# app/jobs/weekly_report_all_shops_job.rb
class WeeklyReportAllShopsJob < ApplicationJob
  queue_as :reports

  # This job runs hourly. It checks each shop's timezone setting
  # and only enqueues the report if it's Monday 8am in the shop's timezone.
  def perform
    Shop.active.find_each do |shop|
      shop_time = Time.current.in_time_zone(shop.timezone)
      report_day = shop.settings["weekly_report_day"] || "monday"

      next unless shop_time.strftime("%A").downcase == report_day
      next unless shop_time.hour == 8

      # Idempotent: skip if report already exists for this week
      week_start = shop_time.to_date.beginning_of_week
      next if WeeklyReport.exists?(shop_id: shop.id, week_start: week_start)

      WeeklyReportJob.perform_later(shop.id)
    end
  end
end
```

### `WebhookDeliveryJob`

```ruby
# app/jobs/webhook_delivery_job.rb
class WebhookDeliveryJob < ApplicationJob
  queue_as :webhooks

  retry_on Net::OpenTimeout, HTTParty::Error,
           wait: :polynomially_longer, attempts: 5

  def perform(endpoint_id, payload)
    endpoint = WebhookEndpoint.find(endpoint_id)

    response = HTTParty.post(
      endpoint.url,
      body: payload.to_json,
      headers: { "Content-Type" => "application/json" },
      timeout: 10
    )

    endpoint.update!(
      last_fired_at: Time.current,
      last_status_code: response.code
    )

    unless response.success?
      raise "Webhook delivery failed: HTTP #{response.code}"
    end
  end
end
```

### `SnapshotCleanupJob` — prevent unbounded snapshot growth

```ruby
# app/jobs/snapshot_cleanup_job.rb
class SnapshotCleanupJob < ApplicationJob
  queue_as :maintenance

  RETENTION_DAYS = 90

  def perform
    cutoff = RETENTION_DAYS.days.ago

    # Delete in batches to avoid long-running transactions
    loop do
      deleted = InventorySnapshot
        .where("snapshotted_at < ?", cutoff)
        .limit(10_000)
        .delete_all

      break if deleted == 0
    end

    Rails.logger.info("[SnapshotCleanup] Cleaned snapshots older than #{cutoff}")
  end
end
```

### Sidekiq Cron Schedule

```yaml
# config/sidekiq.yml
:queues:
  - default
  - reports
  - webhooks
  - maintenance

# config/initializers/sidekiq.rb
Sidekiq.configure_server do |config|
  config.redis = { url: ENV.fetch("REDIS_URL", "redis://localhost:6379/0") }

  config.on(:startup) do
    schedule = {
      "daily_sync" => {
        "cron" => "0 */4 * * *",      # every 4 hours
        "class" => "DailySyncAllShopsJob",
        "description" => "Sync inventory for all active shops"
      },
      "weekly_reports" => {
        "cron" => "0 * * * *",         # hourly — job itself checks shop timezone
        "class" => "WeeklyReportAllShopsJob",
        "description" => "Enqueue weekly reports (timezone-aware)"
      },
      "snapshot_cleanup" => {
        "cron" => "0 3 * * *",         # 3am daily (server time is fine for cleanup)
        "class" => "SnapshotCleanupJob",
        "description" => "Delete snapshots older than 90 days"
      }
    }
    Sidekiq::Cron::Job.load_from_hash(schedule)
  end
end

Sidekiq.configure_client do |config|
  config.redis = { url: ENV.fetch("REDIS_URL", "redis://localhost:6379/0") }
end
```

---

## 6. Frontend — React + Polaris

### Vite Ruby Configuration

```json
// config/vite.json
{
  "all": {
    "sourceCodeDir": "frontend",
    "watchAdditionalPaths": []
  },
  "development": {
    "autoBuild": true,
    "port": 3036
  }
}
```

```typescript
// vite.config.ts
import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";
import ViteRuby from "vite-plugin-ruby";

export default defineConfig({
  plugins: [react(), ViteRuby()],
});
```

### App Entry + Routing (App Bridge v4)

```tsx
// frontend/entrypoints/application.tsx
import React from "react";
import { createRoot } from "react-dom/client";
import App from "../src/App";

const container = document.getElementById("app")!;
createRoot(container).render(<App />);
```

```tsx
// frontend/src/App.tsx
import "@shopify/polaris/build/esm/styles.css";
import { AppProvider } from "@shopify/polaris";
import { BrowserRouter, Routes, Route } from "react-router-dom";

import DashboardPage from "./pages/DashboardPage";
import InventoryPage from "./pages/InventoryPage";
import ReportsPage from "./pages/ReportsPage";
import SuppliersPage from "./pages/SuppliersPage";
import PurchaseOrdersPage from "./pages/PurchaseOrdersPage";
import SettingsPage from "./pages/SettingsPage";

// App Bridge v4: no separate Provider needed.
// The <ui-nav-menu> and session tokens are handled automatically
// when the app is embedded in Shopify Admin.
// See: https://shopify.dev/docs/api/app-bridge-library

export default function App() {
  return (
    <AppProvider i18n={{}}>
      <BrowserRouter>
        <ui-nav-menu>
          <a href="/" rel="home">Dashboard</a>
          <a href="/inventory">Inventory</a>
          <a href="/reports">Reports</a>
          <a href="/suppliers">Suppliers</a>
          <a href="/purchase-orders">Purchase Orders</a>
          <a href="/settings">Settings</a>
        </ui-nav-menu>
        <Routes>
          <Route path="/" element={<DashboardPage />} />
          <Route path="/inventory" element={<InventoryPage />} />
          <Route path="/reports" element={<ReportsPage />} />
          <Route path="/suppliers" element={<SuppliersPage />} />
          <Route path="/purchase-orders" element={<PurchaseOrdersPage />} />
          <Route path="/settings" element={<SettingsPage />} />
        </Routes>
      </BrowserRouter>
    </AppProvider>
  );
}
```

### Authenticated Fetch Hook (App Bridge v4 session tokens)

```tsx
// frontend/src/hooks/useAuthenticatedFetch.ts
import { useCallback } from "react";

const API_BASE = "/api/v1";

// App Bridge v4 automatically injects the session token into fetch requests
// when using shopify.idToken() or the built-in fetch wrapper.
// See: https://shopify.dev/docs/api/app-bridge-library/apis/id-token

async function getSessionToken(): Promise<string> {
  // In App Bridge v4, shopify global is injected into embedded apps
  const token = await shopify.idToken();
  return token;
}

export function useAuthenticatedFetch() {
  return useCallback(async (path: string, options: RequestInit = {}) => {
    const token = await getSessionToken();

    const response = await fetch(`${API_BASE}${path}`, {
      ...options,
      headers: {
        ...options.headers,
        "Content-Type": "application/json",
        Authorization: `Bearer ${token}`,
      },
    });

    if (!response.ok) {
      throw new Error(`API error: ${response.status}`);
    }

    return response.json();
  }, []);
}
```

### Pages

#### `DashboardPage`

```tsx
// frontend/src/pages/DashboardPage.tsx
import { useEffect, useState } from "react";
import {
  Page,
  Layout,
  Card,
  Text,
  Button,
  BlockStack,
  InlineGrid,
  Banner,
  DataTable,
  Badge,
} from "@shopify/polaris";
import { useAuthenticatedFetch } from "../hooks/useAuthenticatedFetch";

interface DashboardData {
  total_skus: number;
  low_stock_count: number;
  out_of_stock_count: number;
  synced_at: string | null;
  low_stock_items: Array<{
    id: number;
    sku: string;
    title: string;
    available: number;
    threshold: number;
  }>;
}

export default function DashboardPage() {
  const fetch = useAuthenticatedFetch();
  const [data, setData] = useState<DashboardData | null>(null);
  const [syncing, setSyncing] = useState(false);

  useEffect(() => {
    fetch("/shop").then(setData);
  }, [fetch]);

  const handleSync = async () => {
    setSyncing(true);
    await fetch("/inventory/sync", { method: "POST" });
    setSyncing(false);
  };

  if (!data) return null;

  const rows = data.low_stock_items.map((item) => [
    item.sku || "—",
    item.title,
    item.available.toString(),
    item.threshold.toString(),
    item.available <= 0 ? (
      <Badge tone="critical">Out of stock</Badge>
    ) : (
      <Badge tone="warning">Low stock</Badge>
    ),
  ]);

  return (
    <Page title="Dashboard">
      <BlockStack gap="400">
        <InlineGrid columns={4} gap="400">
          <Card>
            <Text as="h2" variant="headingMd">Total SKUs</Text>
            <Text as="p" variant="headingLg">{data.total_skus}</Text>
          </Card>
          <Card>
            <Text as="h2" variant="headingMd">Low Stock</Text>
            <Text as="p" variant="headingLg">{data.low_stock_count}</Text>
          </Card>
          <Card>
            <Text as="h2" variant="headingMd">Out of Stock</Text>
            <Text as="p" variant="headingLg">{data.out_of_stock_count}</Text>
          </Card>
          <Card>
            <Text as="h2" variant="headingMd">Last Sync</Text>
            <Text as="p" variant="bodyMd">
              {data.synced_at ? new Date(data.synced_at).toLocaleString() : "Never"}
            </Text>
            <Button onClick={handleSync} loading={syncing}>
              Sync Now
            </Button>
          </Card>
        </InlineGrid>

        <Card>
          <Text as="h2" variant="headingMd">Top Low-Stock Items</Text>
          <DataTable
            columnContentTypes={["text", "text", "numeric", "numeric", "text"]}
            headings={["SKU", "Product", "Available", "Threshold", "Status"]}
            rows={rows}
          />
        </Card>
      </BlockStack>
    </Page>
  );
}
```

#### Page Descriptions (remaining pages)

**`InventoryPage`**
- Filter bar: All / Low Stock / Out of Stock / By Supplier
- Search by product name or SKU
- Paginated table: Product · SKU · Supplier · Available · On Hand · Incoming · Status badge · Actions
- Row actions: View history (sparkline modal) · Set threshold · Assign supplier
- Bulk action: "Generate reorder for selected"

**`ReportsPage`**
- Paginated list of past weekly reports (date, # flagged SKUs, status)
- Report detail view with sections: "What happened this week" (stockouts, highest movers), "What to reorder" (ranked list with suggested quantities), "Risky SKUs" (slow movers + stockout risk), AI commentary block (V2)

**`SuppliersPage`**
- Supplier list with name, email, # linked SKUs, lead time
- Add/Edit supplier modal: name, email, contact name, lead time days, notes
- Per-supplier: list of linked variants

**`PurchaseOrdersPage`**
- "Generate reorder suggestions" button → selects supplier → shows low-stock variants
- Reorder quantity per variant (editable, pre-filled with suggestion)
- Draft email preview panel (editable textarea)
- Send button → confirms + fires email

**`SettingsPage`**
- Notification email
- Default low-stock threshold
- Weekly report day + time
- Timezone selector
- Webhook endpoints manager (add/remove URL + event type)
- Danger zone: disconnect store

---

## 7. Shopify Integration

### App Setup Checklist

```
□ Create app in Shopify Partner Dashboard
□ Set App URL: https://app.yourdomain.com
□ Set Redirect URL: https://app.yourdomain.com/auth/shopify/callback
□ Required scopes:
    read_products
    read_inventory
    read_orders        (V2 — customer DNA)
    read_customers     (V2 — customer DNA)
□ Pin API version: 2025-01
□ Webhooks (registered automatically by shopify_app gem):
    app/uninstalled         → /api/webhooks/app_uninstalled
    products/update         → /api/webhooks/products_update
    products/delete         → /api/webhooks/products_delete
□ GDPR mandatory webhooks:
    customers/data_request  → /api/webhooks/customers_data_request
    customers/redact        → /api/webhooks/customers_redact
    shop/redact             → /api/webhooks/shop_redact
```

### Security Requirements (Shopify App Review)

| Requirement | Implementation |
|---|---|
| **Encrypted access tokens** | `encrypts :access_token` in Shop model (Rails 7 encrypted attributes, backed by `RAILS_MASTER_KEY`) |
| **Session token auth** | `shopify_app` gem + `ShopifyApp::EnsureHasSession` verifies App Bridge JWT on every API request |
| **No trusted headers** | Auth comes from JWT only — no `X-Shop-Domain` header trust |
| **Webhook HMAC verification** | `ShopifyApp::WebhookVerification` concern on all webhook controllers verifies `X-Shopify-Hmac-SHA256` |
| **GDPR webhooks** | `customers/data_request`, `customers/redact`, `shop/redact` all handled |
| **Multi-tenant isolation** | `acts_as_tenant :shop` on all models + `ActsAsTenant.current_tenant` set in controller |
| **Token cleanup on uninstall** | `app/uninstalled` webhook clears access token immediately |

### Shopify GraphQL Admin API — Key Queries

All Shopify API calls use **GraphQL** exclusively. No REST API calls. This reduces API cost (one query fetches products + variants + inventory levels together) and aligns with Shopify's direction.

| Data | GraphQL Query | Notes |
|---|---|---|
| Products + variants + inventory | `products` with nested `variants.inventoryItem.inventoryLevels` | Single paginated query fetches everything |
| Webhook registration | `webhookSubscriptionCreate` mutation | Handled by `shopify_app` gem |
| Shop info | `shop` query | For timezone, plan, etc. |

### Rate Limit Strategy

Shopify's GraphQL API uses a cost-based throttle bucket (1,000 points, restores at 50/sec for standard apps).

- **Cost awareness:** The `products(first: 50)` query with nested variants + inventory costs ~100-200 points. Using `first: 50` instead of `first: 250` keeps individual query costs manageable.
- **Automatic throttle handling:** `Shopify::GraphqlClient` detects `THROTTLED` errors and retries with exponential backoff (2s, 4s, 6s).
- **Job-level retries:** `InventorySyncJob` has separate `retry_on` for throttle errors with up to 5 attempts.
- **Staggered syncs:** `DailySyncAllShopsJob` enqueues individual shop syncs as separate jobs — Sidekiq processes them sequentially per queue, naturally spacing API calls.

### Embedded App (App Bridge v4)

App Bridge v4 replaces the v2/v3 `createApp()` + `<Provider>` pattern. In v4:

- The `shopify` global is automatically injected into embedded apps
- Session tokens are obtained via `shopify.idToken()`
- Navigation uses `<ui-nav-menu>` web component (no React provider needed)
- No `forceRedirect` or `shopOrigin` configuration required
- OAuth bounce is handled by `shopify_app` gem server-side

---

## 8. AI Layer

### Architecture

```
Shop inventory metrics (JSON)
        │
        ▼
Claude API (claude-sonnet-4-20250514)
  System prompt: inventory analyst persona
  User prompt: structured metrics JSON
        │
        ▼
Natural language insights (3–5 bullets)
        │
        ▼
Cached in weekly_reports.payload['ai_commentary']
```

### AI Insights Generator (V2)

```ruby
# app/services/ai/insights_generator.rb
module AI
  class InsightsGenerator
    SYSTEM_PROMPT = <<~PROMPT
      You are an inventory analyst for a Shopify merchant.
      Given structured inventory data, produce 3-5 concise, actionable bullet points.
      Focus on: reorder urgency, stockout risk, and top opportunities.
      Be specific — mention SKUs or product names where relevant.
      Return only the bullet points, no preamble.
    PROMPT

    def initialize(shop)
      @shop = shop
    end

    def generate
      metrics = build_metrics
      response = Anthropic::Client.new.messages(
        model: "claude-sonnet-4-20250514",
        max_tokens: 500,
        system: SYSTEM_PROMPT,
        messages: [{ role: "user", content: metrics.to_json }]
      )
      response.content.first.text
    rescue Anthropic::Error => e
      Rails.logger.error("[AI::InsightsGenerator] Claude API error: #{e.message}")
      "AI insights temporarily unavailable."
    end

    private

    def build_metrics
      detector = Inventory::LowStockDetector.new(@shop)
      all_variants = detector.detect

      low_stock = all_variants.select { |v| v[:status] == :low_stock }
      out_of_stock = all_variants.select { |v| v[:status] == :out_of_stock }

      {
        shop: @shop.shop_domain,
        week_start: Date.current.beginning_of_week.to_s,
        total_skus: @shop.variants.count,
        low_stock_count: low_stock.size,
        out_of_stock_count: out_of_stock.size,
        top_low_stock: low_stock.first(10).map { |v|
          { sku: v[:variant].sku, title: v[:variant].title, available: v[:available], threshold: v[:threshold] }
        },
        out_of_stock_items: out_of_stock.first(10).map { |v|
          { sku: v[:variant].sku, title: v[:variant].title }
        }
      }
    end
  end
end
```

### Purchase Order Draft Generation (V2)

```ruby
# app/services/ai/po_draft_generator.rb
module AI
  class PoDraftGenerator
    SYSTEM_PROMPT = <<~PROMPT
      You are a purchasing assistant. Generate a professional purchase order email
      to a supplier. Include a table of SKUs and quantities. Be concise and professional.
      Return only the email body (no subject line).
    PROMPT

    def generate(supplier:, line_items:, shop:)
      prompt = {
        supplier_name: supplier.name,
        supplier_email: supplier.email,
        shop_name: shop.shop_domain,
        line_items: line_items.map { |li|
          { sku: li.sku, product: li.title, qty: li.qty_ordered }
        },
        target_delivery: (Date.current + supplier.lead_time_days.days).strftime("%B %d, %Y")
      }

      response = Anthropic::Client.new.messages(
        model: "claude-sonnet-4-20250514",
        max_tokens: 600,
        system: SYSTEM_PROMPT,
        messages: [{ role: "user", content: prompt.to_json }]
      )
      response.content.first.text
    rescue Anthropic::Error => e
      Rails.logger.error("[AI::PoDraftGenerator] Claude API error: #{e.message}")
      fallback_draft(supplier: supplier, line_items: line_items, shop: shop)
    end

    private

    def fallback_draft(supplier:, line_items:, shop:)
      items_table = line_items.map { |li|
        "- #{li.sku}: #{li.title} — Qty: #{li.qty_ordered}"
      }.join("\n")

      <<~EMAIL
        Dear #{supplier.name},

        We would like to place the following order:

        #{items_table}

        Please confirm availability and expected delivery date.

        Best regards,
        #{shop.shop_domain}
      EMAIL
    end
  end
end
```

---

## 9. Environment & Config

### `.env`
```bash
# Shopify
SHOPIFY_API_KEY=your_api_key
SHOPIFY_API_SECRET=your_api_secret
SHOPIFY_APP_URL=https://app.yourdomain.com

# Database
DATABASE_URL=postgresql://localhost/shopify_inventory_production

# Redis + Sidekiq
REDIS_URL=redis://localhost:6379/0

# Email
SENDGRID_API_KEY=your_sendgrid_key
MAIL_FROM=noreply@yourdomain.com

# AI (V2)
ANTHROPIC_API_KEY=your_anthropic_key

# Rails
SECRET_KEY_BASE=your_rails_secret
RAILS_MASTER_KEY=your_master_key  # used for encrypts :access_token
RAILS_ENV=production
```

> **Note:** `RAILS_MASTER_KEY` encrypts the access tokens at rest. In production, set this as an environment variable — do not commit `config/master.key` to version control.

### Vite Environment

With the monorepo approach (Vite Ruby), frontend environment variables are set in the same `.env` file. Vite Ruby automatically exposes `VITE_`-prefixed variables to the frontend build.

```bash
# Exposed to frontend at build time
VITE_SHOPIFY_API_KEY=your_api_key
```

---

## 10. Testing

### Backend (RSpec)

```ruby
# Key test files
spec/
├── models/
│   ├── shop_spec.rb
│   ├── product_spec.rb
│   ├── variant_spec.rb
│   └── inventory_snapshot_spec.rb
├── services/
│   ├── shopify/
│   │   ├── inventory_fetcher_spec.rb
│   │   └── graphql_client_spec.rb
│   ├── inventory/
│   │   ├── persister_spec.rb
│   │   ├── snapshotter_spec.rb
│   │   └── low_stock_detector_spec.rb
│   ├── notifications/
│   │   └── alert_sender_spec.rb
│   └── reports/
│       └── weekly_generator_spec.rb
├── jobs/
│   ├── inventory_sync_job_spec.rb
│   ├── weekly_report_job_spec.rb
│   ├── snapshot_cleanup_job_spec.rb
│   └── webhook_delivery_job_spec.rb
├── controllers/
│   ├── webhooks_controller_spec.rb
│   ├── gdpr_controller_spec.rb
│   └── health_controller_spec.rb
└── requests/
    └── api/v1/
        ├── products_spec.rb
        ├── inventory_spec.rb
        ├── suppliers_spec.rb
        └── purchase_orders_spec.rb
```

### Key Test Cases

```ruby
# spec/services/inventory/low_stock_detector_spec.rb
RSpec.describe Inventory::LowStockDetector do
  let(:shop) { create(:shop, settings: { "low_stock_threshold" => 10 }) }

  before { ActsAsTenant.current_tenant = shop }

  it "flags variants below shop-level threshold" do
    variant = create(:variant, shop: shop)
    create(:inventory_snapshot, shop: shop, variant: variant, available: 5)

    results = described_class.new(shop).detect
    item = results.find { |r| r[:variant].id == variant.id }

    expect(item[:status]).to eq(:low_stock)
  end

  it "uses variant-level override when set" do
    variant = create(:variant, shop: shop, low_stock_threshold: 3)
    create(:inventory_snapshot, shop: shop, variant: variant, available: 5)

    results = described_class.new(shop).detect
    item = results.find { |r| r[:variant].id == variant.id }

    expect(item[:status]).to eq(:ok)
  end

  it "marks zero-stock variants as out_of_stock" do
    variant = create(:variant, shop: shop)
    create(:inventory_snapshot, shop: shop, variant: variant, available: 0)

    results = described_class.new(shop).detect
    item = results.find { |r| r[:variant].id == variant.id }

    expect(item[:status]).to eq(:out_of_stock)
  end
end
```

```ruby
# spec/controllers/webhooks_controller_spec.rb
RSpec.describe WebhooksController, type: :request do
  let(:shop) { create(:shop) }
  let(:secret) { ENV.fetch("SHOPIFY_API_SECRET") }

  def sign_payload(body)
    Base64.strict_encode64(
      OpenSSL::HMAC.digest("sha256", secret, body)
    )
  end

  describe "POST /api/webhooks/app_uninstalled" do
    it "marks shop as uninstalled with valid HMAC" do
      body = { shop_domain: shop.shop_domain }.to_json
      hmac = sign_payload(body)

      post "/api/webhooks/app_uninstalled",
           params: body,
           headers: {
             "X-Shopify-Hmac-SHA256" => hmac,
             "X-Shopify-Shop-Domain" => shop.shop_domain,
             "Content-Type" => "application/json"
           }

      expect(response).to have_http_status(:ok)
      expect(shop.reload.uninstalled_at).to be_present
    end

    it "rejects requests with invalid HMAC" do
      body = { shop_domain: shop.shop_domain }.to_json

      post "/api/webhooks/app_uninstalled",
           params: body,
           headers: {
             "X-Shopify-Hmac-SHA256" => "invalid",
             "Content-Type" => "application/json"
           }

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "POST /api/webhooks/products_delete" do
    it "soft-deletes the product" do
      product = create(:product, shop: shop, shopify_product_id: 12345)
      body = { id: 12345 }.to_json
      hmac = sign_payload(body)

      post "/api/webhooks/products_delete",
           params: body,
           headers: {
             "X-Shopify-Hmac-SHA256" => hmac,
             "X-Shopify-Shop-Domain" => shop.shop_domain,
             "Content-Type" => "application/json"
           }

      expect(response).to have_http_status(:ok)
      expect(product.reload.deleted_at).to be_present
    end
  end
end
```

```ruby
# spec/jobs/inventory_sync_job_spec.rb
RSpec.describe InventorySyncJob do
  let(:shop) { create(:shop) }

  it "retries on Shopify throttle errors" do
    allow(Shopify::InventoryFetcher).to receive(:new)
      .and_raise(Shopify::GraphqlClient::ShopifyThrottledError)

    expect {
      described_class.perform_now(shop.id)
    }.to raise_error(Shopify::GraphqlClient::ShopifyThrottledError)

    # ActiveJob retry_on will handle the retry automatically
  end

  it "discards if shop not found" do
    expect {
      described_class.perform_now(-1)
    }.not_to raise_error
  end
end
```

### Frontend (Vitest + React Testing Library)

```
frontend/src/
├── pages/__tests__/
│   ├── DashboardPage.test.tsx
│   └── InventoryPage.test.tsx
└── components/__tests__/
    ├── LowStockBadge.test.tsx
    └── ReorderSuggestions.test.tsx
```

### Error Monitoring

Integrate **Sentry** for production error tracking:

```ruby
# Gemfile
gem "sentry-ruby"
gem "sentry-rails"
gem "sentry-sidekiq"

# config/initializers/sentry.rb
Sentry.init do |config|
  config.dsn = ENV["SENTRY_DSN"]
  config.breadcrumbs_logger = [:active_support_logger, :http_logger]
  config.traces_sample_rate = 0.1
  config.profiles_sample_rate = 0.1
end
```

---

## 11. Deployment

### Docker Setup (API-only — no asset precompile)

```dockerfile
# Dockerfile
FROM ruby:3.3-slim

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    postgresql-client \
    nodejs \
    npm \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Install Ruby dependencies
COPY Gemfile Gemfile.lock ./
RUN bundle install --without development test

# Install JS dependencies + build frontend via Vite Ruby
COPY package.json package-lock.json ./
RUN npm ci
COPY . .
RUN bundle exec vite build

# No `rails assets:precompile` — this is an API-mode app.
# Frontend is built by Vite Ruby above.

CMD ["bundle", "exec", "puma", "-C", "config/puma.rb"]
```

```yaml
# docker-compose.yml
services:
  web:
    build: .
    ports: ["3000:3000"]
    env_file: .env
    depends_on: [db, redis]
    command: bundle exec puma -C config/puma.rb

  worker:
    build: .
    command: bundle exec sidekiq -C config/sidekiq.yml
    env_file: .env
    depends_on: [db, redis]

  db:
    image: postgres:16
    volumes: [pgdata:/var/lib/postgresql/data]
    environment:
      POSTGRES_DB: shopify_inventory
      POSTGRES_PASSWORD: postgres

  redis:
    image: redis:7-alpine

volumes:
  pgdata:
```

### Recommended Hosting

| Service | What |
|---|---|
| Railway or Render | Rails app + Sidekiq worker (single repo, two services) |
| Supabase or Railway | PostgreSQL |
| Upstash | Redis (serverless) |
| SendGrid | Transactional email |
| Sentry | Error monitoring |

> **Single origin:** Because frontend is served by Rails via Vite Ruby, there's no separate frontend deployment. One domain, one deploy, no CORS.

---

## 12. Phased Build Plan

### Phase 0 — Setup (Days 1–2)
- [ ] `rails new shopify-inventory --api --database=postgresql`
- [ ] Add `vite_rails` gem + `npm create vite@latest` for frontend
- [ ] Install: `shopify_app`, `acts_as_tenant`, `kaminari`, `sidekiq`, `sidekiq-cron`
- [ ] Install Polaris: `npm install @shopify/polaris react-router-dom`
- [ ] Register app in Shopify Partner Dashboard, pin API version `2025-01`
- [ ] Docker Compose running locally
- [ ] Sentry integration

### Phase 1 — Auth + Security (Days 3–6)
- [ ] `shops` table with encrypted `access_token`
- [ ] `shopify_app` gem initializer + OAuth flow
- [ ] `AuthenticatedController` with session token JWT verification
- [ ] `WebhooksController` with HMAC verification
- [ ] `GdprController` for mandatory GDPR webhooks
- [ ] `acts_as_tenant` setup on all models
- [ ] Health check endpoint
- [ ] Frontend shell with App Bridge v4 + `ui-nav-menu`

**Milestone:** Install on dev store → lands on connected dashboard. Webhooks registered. HMAC verified. ✓

### Phase 2 — Inventory Sync (Days 7–12)
- [ ] `products`, `variants`, `inventory_snapshots` tables with indexes
- [ ] `Shopify::GraphqlClient` with rate limit handling
- [ ] `Shopify::InventoryFetcher` (all GraphQL, products + inventory in one query)
- [ ] `Inventory::Persister` + `Inventory::Snapshotter`
- [ ] `InventorySyncJob` + `DailySyncAllShopsJob`
- [ ] `SnapshotCleanupJob` (90-day retention)
- [ ] Products + variants API endpoints with pagination
- [ ] Inventory dashboard page + table
- [ ] "Sync Now" button
- [ ] `products/update` + `products/delete` webhook handlers

**Milestone:** Click sync → real products appear with inventory levels. Paginated. Low stock flagged. ✓

### Phase 3 — Alerts (Days 13–16)
- [ ] `alerts` table
- [ ] `Inventory::LowStockDetector` (subquery-based, no N+1)
- [ ] `Notifications::AlertSender`
- [ ] `AlertMailer` (SendGrid)
- [ ] Settings page: threshold + alert email + timezone
- [ ] Alert history tab

**Milestone:** Item drops below threshold → email arrives. No duplicate alerts within same day. ✓

### Phase 4 — Reports (Days 17–21)
- [ ] `weekly_reports` table
- [ ] `Reports::WeeklyGenerator` (complete implementation)
- [ ] `WeeklyReportJob` + `WeeklyReportAllShopsJob` (timezone-aware)
- [ ] `ReportMailer`
- [ ] Reports list + detail pages

**Milestone:** Report auto-generates at 8am in shop's timezone on configured day → email + in-app view. ✓

### Phase 5 — Suppliers + POs (Days 22–27)
- [ ] `suppliers` + `purchase_orders` + `purchase_order_line_items` tables
- [ ] Supplier CRUD API + page
- [ ] Reorder quantity calculator
- [ ] Draft PO email template (rule-based, no AI yet)
- [ ] PO send endpoint + `PurchaseOrderMailer`
- [ ] Purchase orders page with draft/send UI

**Milestone:** Assign supplier to product → generate draft PO with line items → send email. ✓

### Phase 6 — AI Layer (Days 28–32)
- [ ] `AI::InsightsGenerator` (Claude API with error fallback)
- [ ] `AI::PoDraftGenerator` (replaces template, with fallback)
- [ ] Cache insights in `weekly_reports.payload`
- [ ] AI insights card on dashboard
- [ ] AI commentary section in reports

**Milestone:** AI bullets appear on dashboard. PO drafts are LLM-generated with graceful fallback. ✓

### Phase 7 — Webhooks + Customer DNA (Days 33–38)
- [ ] `webhook_endpoints` table + API
- [ ] `WebhookDeliveryJob` with retries
- [ ] Webhook settings UI
- [ ] `customers` table
- [ ] Order history sync from Shopify
- [ ] Customer stats computation
- [ ] Customers list + profile page

**Milestone:** Webhooks fire on events. Customer profiles populated from order history. ✓

---

*Total estimated time: 5–6 weeks for a solid V1 + V2 foundation.*
