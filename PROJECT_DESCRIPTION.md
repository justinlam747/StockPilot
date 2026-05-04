# StockPilot Project Description

## Overview

StockPilot is a Ruby on Rails Shopify application for inventory operations. It connects to a Shopify merchant store, syncs product and variant inventory through the Shopify Admin GraphQL API, stores point-in-time inventory snapshots, detects low-stock and out-of-stock conditions, creates merchant-facing alerts, supports supplier management, and tracks purchase order workflows.

The project is positioned as an "inventory intelligence" app for Shopify merchants. The core product promise is to help merchants avoid stockouts by turning Shopify inventory data into operational actions: alerts, reorder suggestions, purchase order follow-up, supplier assignment, and agent-generated summaries.

The application is mostly server-rendered Rails with custom CSS and lightweight JavaScript. It uses Sidekiq and Redis for background processing, PostgreSQL for relational storage and inventory history, and `acts_as_tenant` for shop-scoped multi-tenancy.

## Core Capabilities

- Shopify OAuth connection using OmniAuth.
- Shopify Admin GraphQL product and inventory sync.
- Product and variant persistence with support for Shopify batch sync and product webhooks.
- Inventory snapshot history for variant stock quantities.
- Low-stock and out-of-stock detection based on shop-wide or variant-level thresholds.
- Alert records and optional email notification delivery.
- Dashboard metrics for products, variants, alerts, purchase orders, and stock health.
- Inventory browsing with pagination, search, stock filters, sort options, grid/table partial rendering, and product-level history.
- Supplier management with lead times, contact data, phone, star rating, and notes.
- Purchase order lifecycle management for draft, sent, received, and cancelled states.
- Agent run tracking for inventory monitoring, recommendation generation, progress events, and proposed actions.
- Shopify webhook handling for product updates, product deletes, app uninstall, and GDPR compliance webhooks.
- Audit logging for security-relevant events.
- Security controls including HMAC verification, encrypted Shopify tokens, rate limiting, filtered params, CORS configuration, and security headers.

## Technology Stack

| Layer | Technology |
| --- | --- |
| Backend framework | Ruby on Rails 7.2.3 |
| Ruby version | Ruby 3.3+ |
| Database | PostgreSQL |
| Search/indexing | PostgreSQL `pg_trgm` indexes on product titles and variant SKUs |
| Background jobs | Sidekiq 7, Active Job, Redis |
| Job scheduling | sidekiq-cron |
| Shopify integration | `shopify_api`, `omniauth-shopify-oauth2` |
| Multi-tenancy | `acts_as_tenant` scoped by `Shop` |
| Caching | Rails cache, Redis-backed outside test |
| Pagination | Kaminari |
| HTTP clients | HTTParty and Shopify API client |
| Security | Rack::Attack, Brakeman, bundler-audit, Rails encryption |
| Monitoring | Sentry Rails, Sentry Ruby, Sentry Sidekiq |
| Tests | RSpec, FactoryBot, Shoulda Matchers, WebMock, SimpleCov |
| Frontend | Rails ERB views, Propshaft assets, custom CSS, HTMX, vanilla JS |
| Landing animations | GSAP and ScrollTrigger loaded from CDN |
| E2E utilities | Puppeteer scripts under `test/e2e` and `scripts` |

## High-Level Architecture

```text
Merchant / Shopify Admin
        |
        | OAuth install and app usage
        v
Rails controllers
        |
        +-- ConnectionsController handles Shopify OAuth callback
        +-- DashboardController renders operational metrics
        +-- InventoryController renders product and stock views
        +-- SuppliersController manages supplier records
        +-- PurchaseOrdersController manages PO lifecycle
        +-- AlertsController displays and dismisses alerts
        +-- AgentsController starts and displays inventory agent runs
        +-- WebhooksController receives Shopify product/app webhooks
        +-- GdprController receives required Shopify privacy webhooks
        |
        v
Service layer
        |
        +-- Shopify::GraphqlClient
        +-- Shopify::InventoryFetcher
        +-- Shopify::WebhookRegistrar
        +-- Inventory::Persister
        +-- Inventory::Snapshotter
        +-- Inventory::LowStockDetector
        +-- Notifications::AlertSender
        +-- Reports::WeeklyGenerator
        +-- Cache::ShopCache
        +-- Agents::Runner / InventoryMonitor / SummaryClient / RunLogger
        |
        v
PostgreSQL and Redis
        |
        +-- PostgreSQL stores shops, products, variants, snapshots, alerts,
            suppliers, purchase orders, audit logs, and agent runtime state.
        +-- Redis backs Sidekiq and cache/throttle storage.
```

## Main User Flows

### 1. Shopify Connection

The landing page contains a Shopify connection form that posts to `/auth/shopify`. OmniAuth normalizes the submitted shop domain and starts the Shopify OAuth flow.

After Shopify redirects back to `/auth/shopify/callback`, `ConnectionsController#shopify_callback` upserts a `Shop` record by `shop_domain`, stores the encrypted access token, sets `session[:shopify_domain]`, records a `shop_connected` audit event, and redirects the merchant to `/dashboard`.

The `AfterAuthenticateJob` exists to register webhooks and start an initial `InventorySyncJob`, but the current OAuth callback does not enqueue that job. That is an important integration point to wire if automatic post-install sync is expected.

### 2. Inventory Sync

`InventorySyncJob` is the central sync job. It:

1. Finds an active shop.
2. Runs inside `ActsAsTenant.with_tenant(shop)`.
3. Fetches product and variant inventory through `Shopify::InventoryFetcher`.
4. Persists products and variants through `Inventory::Persister`.
5. Creates point-in-time rows through `Inventory::Snapshotter`.
6. Runs `Inventory::LowStockDetector`.
7. Creates alerts and sends email through `Notifications::AlertSender`.
8. Updates `shop.synced_at`.
9. Warms cached dashboard inventory stats.

The Shopify GraphQL client handles cursor pagination and retries throttled requests.

### 3. Inventory Browsing

`InventoryController#index` builds the product list from model scopes. It supports:

- stock status filter: all, low stock, out of stock;
- search by product title or variant SKU;
- sort by title, newest, or vendor;
- pagination;
- HTMX partial rendering for grid/table updates.

The controller avoids loading entire snapshot histories by attaching a temporary `current_stock` value to each displayed variant using `InventorySnapshot.latest_per_variant`.

`InventoryController#show` loads a product with variants, suppliers, and snapshots, then prepares 14 days of daily total stock data through `InventorySnapshot.daily_totals`.

### 4. Alerts

Alerts represent low-stock or out-of-stock notifications for a variant. Alerts can be active or dismissed.

`Notifications::AlertSender` deduplicates alerts so the same variant is not alerted more than once per day. If the shop has an alert email configured, it delivers `AlertMailer.low_stock` asynchronously.

`AlertsController#index` displays paginated alerts with status and severity filters. `AlertsController#dismiss` marks an alert dismissed, records an audit log, and can render an HTMX row update.

### 5. Suppliers

Suppliers are shop-scoped vendor/contact records. A supplier can have many variants and many purchase orders.

`SuppliersController` supports create, update, delete, and index. It uses `Cache::ShopCache` for supplier list caching and write-through updates. Suppliers can store:

- name;
- email;
- phone;
- contact name;
- lead time in days;
- star rating;
- notes and rating notes.

Destroying a supplier is restricted if purchase orders reference it.

### 6. Purchase Orders

Purchase orders are restock records tied to a supplier and a shop. They have line items for variants and support these statuses:

- `draft`;
- `sent`;
- `received`;
- `cancelled`.

`PurchaseOrdersController#index` lists orders with optional status filtering. `show` displays the order with line items and product context. `mark_sent` records `sent_at` and changes status to `sent`; `mark_received` changes status to `received`.

The model sets `order_date` and `draft` status by default on create, validates expected delivery date ordering, and validates line item quantities and prices.

### 7. Inventory Agent Runs

The agent subsystem persists operational inventory-monitoring runs.

`Agents::Runner` creates or reuses an active run for a shop, uses a PostgreSQL advisory transaction lock to avoid duplicate concurrent enqueues, records the goal/correction payload, and enqueues `AgentRunJob`.

`AgentRunJob` claims queued runs, marks them running, and delegates to `Agents::InventoryMonitor`.

`Agents::InventoryMonitor`:

- logs progress events through `Agents::RunLogger`;
- detects flagged variants;
- applies simple correction rules from operator text, such as focusing only on out-of-stock items or ignoring supplierless SKUs;
- groups reorder recommendations by supplier;
- creates proposed `AgentAction` records;
- builds a structured result payload;
- generates a summary through `Agents::SummaryClient`;
- marks the run completed.

`Agents::SummaryClient` can use OpenAI, Anthropic, or a deterministic fallback summary depending on environment variables. The fallback path means the agent feature still works without an AI provider configured.

### 8. Webhooks

`WebhooksController` receives Shopify webhooks at `/webhooks/:topic`. It verifies `X-Shopify-Hmac-SHA256` with the app secret before dispatching.

Handled topics:

- `app_uninstalled`: marks the shop uninstalled and clears the token.
- `products_update`: normalizes and persists product/variant data from the webhook payload.
- `products_delete`: soft-deletes the product by setting `deleted_at`.

`Shopify::WebhookRegistrar` can register:

- `app/uninstalled`;
- `products/update`;
- `products/delete`.

### 9. GDPR Compliance

`GdprController` handles Shopify-required privacy webhooks:

- `/gdpr/customers_data_request`;
- `/gdpr/customers_redact`;
- `/gdpr/shop_redact`.

The customer jobs record audit events and explicitly document that the app does not store customer PII. `GdprShopRedactJob` deletes shop-scoped tenant data and then destroys the `Shop`.

## Domain Model

### Shop

`Shop` is the tenant root. It stores the Shopify domain, encrypted access token, plan, install/uninstall timestamps, sync timestamp, and JSON settings.

Important behavior:

- validates `*.myshopify.com` domains;
- encrypts `access_token` using Rails encryption;
- owns products, variants, snapshots, suppliers, alerts, purchase orders, audit logs, and agent runs;
- exposes settings helpers for timezone, low-stock threshold, and alert email.

### Product

`Product` represents a Shopify product synced into StockPilot.

Important behavior:

- scoped to current shop via `acts_as_tenant`;
- has many variants;
- supports soft delete through `deleted_at`;
- validates title and Shopify product id for Shopify-sourced records;
- provides scopes for active products, low-stock products, out-of-stock products, and title/SKU search.

### Variant

`Variant` represents a Shopify SKU or option combination.

Important behavior:

- scoped to current shop;
- belongs to product;
- optionally belongs to supplier;
- has snapshots, alerts, and purchase order line items;
- supports an optional per-variant low-stock threshold;
- exposes a temporary `current_stock` attribute used by inventory views.

### InventorySnapshot

`InventorySnapshot` is a point-in-time stock record for a variant.

Tracked quantities:

- available;
- on hand;
- committed;
- incoming.

Important behavior:

- `latest_per_variant` uses PostgreSQL `DISTINCT ON` to efficiently select the newest snapshot for each variant;
- requested columns are whitelisted to prevent SQL injection;
- `count_by_stock_status` performs fast aggregate counts for dashboards;
- `daily_totals` prepares chart data with zero-filled missing dates.

### Alert

`Alert` tracks low-stock and out-of-stock notifications.

Important behavior:

- supports `low_stock` and `out_of_stock` alert types;
- stores threshold and current quantity at trigger time;
- can be dismissed;
- exposes severity and user-facing message helpers.

### Supplier

`Supplier` stores vendor and replenishment metadata for a shop.

Important behavior:

- variants become supplierless if their supplier is deleted;
- purchase orders restrict supplier deletion;
- validates email, lead time, and rating.

### PurchaseOrder and PurchaseOrderLineItem

`PurchaseOrder` represents a supplier reorder workflow. `PurchaseOrderLineItem` stores SKU-level quantities and pricing.

Important behavior:

- purchase orders belong to supplier and shop;
- line items belong to purchase order and variant;
- purchase orders accept nested line item attributes;
- status is constrained to draft, sent, received, or cancelled.

### AuditLog

`AuditLog` stores security and compliance events. Persisted audit logs are immutable by overriding `readonly?`.

Captured metadata can include:

- action;
- shop;
- IP address;
- user agent;
- request id;
- JSON metadata.

### Agent Runtime Tables

The agent runtime is stored across:

- `agent_runs`: one execution, goal, status, progress, timestamps, summary, payloads;
- `agent_events`: ordered timeline events for a run;
- `agent_actions`: proposed or resolved operational actions from a run.

## Database Tables

Current schema includes:

- `shops`;
- `products`;
- `variants`;
- `inventory_snapshots`;
- `alerts`;
- `suppliers`;
- `purchase_orders`;
- `purchase_order_line_items`;
- `audit_logs`;
- `agent_runs`;
- `agent_events`;
- `agent_actions`.

The schema enables PostgreSQL extensions:

- `plpgsql`;
- `pg_trgm`.

Notable indexes include:

- unique shop domain;
- unique product by shop and Shopify product id;
- unique variant by shop and Shopify variant id;
- shop/status indexes for products, alerts, purchase orders, and agent runs;
- time-based indexes for snapshots and audit logs;
- trigram indexes on product title and variant SKU;
- ordered event sequence uniqueness per agent run.

## Background Jobs

| Job | Queue | Purpose |
| --- | --- | --- |
| `InventorySyncJob` | default | Fetch Shopify inventory, persist products/variants/snapshots, detect alerts, warm stats cache. |
| `DailySyncAllShopsJob` | default | Enqueue an inventory sync for every active shop. |
| `SnapshotCleanupJob` | maintenance | Delete inventory snapshots older than 90 days in batches. |
| `AfterAuthenticateJob` | default | Register webhooks and enqueue initial inventory sync after OAuth. Present but not currently called by the callback. |
| `AgentRunJob` | default | Execute an inventory agent run and persist progress/actions/results. |
| `GdprCustomerDataJob` | default | Process customer data request webhook and record audit event. |
| `GdprCustomerRedactJob` | default | Process customer redact webhook and record audit event. |
| `GdprShopRedactJob` | default | Delete all tenant data and destroy the shop record. |

Sidekiq is configured with these queues:

- `default`;
- `reports`;
- `webhooks`;
- `maintenance`.

The Sidekiq cron initializer schedules:

- `DailySyncAllShopsJob` every 4 hours;
- `WeeklyReportJob` every Monday at 09:00 UTC;
- `SnapshotCleanupJob` daily at 03:00 UTC.

`WeeklyReportJob` is referenced in the Sidekiq schedule but is not present in the current app code.

## Frontend and UX

The application uses Rails ERB templates rather than a separate SPA framework.

Main UI areas:

- public animated landing page;
- app shell with sidebar navigation;
- dashboard KPI cards and recent alerts;
- inventory grid/table views;
- product detail view with snapshot trend data;
- suppliers management view;
- purchase order list/detail pages;
- alerts view;
- settings view;
- agents index/detail pages.

Frontend implementation details:

- `app/views/layouts/application.html.erb` loads app CSS, HTMX, sidebar JS, and toast JS.
- `app/views/layouts/landing.html.erb` loads landing CSS, Inter font, GSAP, ScrollTrigger, and landing animations.
- `app/assets/stylesheets/overrides.css` contains the main app design system.
- `app/assets/stylesheets/landing.css` contains landing page styles.
- `sidebar.js` handles hover expansion on desktop and drawer behavior on mobile.
- `toasts.js` exposes `window.StockPilot.toast` and listens for agent completion events.
- Inventory, suppliers, and alerts support partial updates through HTMX request handling.

## Security and Compliance

Implemented security controls include:

- Shopify webhook HMAC verification for product/app webhooks.
- HMAC verification for GDPR webhooks.
- encrypted Shopify access tokens through Rails model encryption.
- tenant isolation through `acts_as_tenant`.
- Rack::Attack request throttling.
- audit logging for important operational and security events.
- parameter filtering for tokens and secrets.
- CORS initializer.
- security headers initializer.
- Brakeman and bundler-audit CI jobs.
- snapshot retention cleanup.
- GDPR customer and shop redaction handlers.

Important security caveats:

- The security documentation describes embedded Shopify iframe behavior, but the current `security_headers.rb` sets `X-Frame-Options: DENY` and `frame-ancestors 'none'`. That conflicts with an embedded Shopify app expectation.
- `Rack::Attack::SHOP_OR_IP` checks `session[:shop_id]`, but the OAuth callback currently stores `session[:shopify_domain]`. This means throttling may fall back to IP instead of true per-shop identity.
- Resource-level authorization through a policy layer such as Pundit is documented as not implemented.

## Caching Strategy

`Cache::ShopCache` provides per-shop cache keys:

- product list and product detail cache with 6 hour TTL;
- supplier list and supplier detail cache with 12 hour TTL;
- inventory stats cache with 2 minute TTL.

The app uses a mix of:

- write-through cache updates for products and suppliers;
- cache-aside reads for inventory stats;
- explicit invalidation after inventory sync or supplier changes.

## Testing and Quality

The project has a broad RSpec test suite covering:

- models;
- services;
- jobs;
- mailers;
- request specs;
- integration pipelines;
- security headers and Brakeman execution;
- error handling and resilience;
- concurrency and idempotency cases.

SimpleCov is configured in `spec/rails_helper.rb` with an 80 percent minimum coverage gate.

GitHub Actions CI includes:

- RuboCop linting;
- bundler-audit;
- Brakeman;
- RSpec with PostgreSQL 16 and Redis 7 service containers;
- coverage artifact upload.

The repository also contains Puppeteer-based E2E/debug scripts and screenshot artifacts under `test/e2e` and `scripts`.

## Local Development

Primary commands are exposed in `package.json`:

```bash
npm run dev
npm run rails
npm run sidekiq
npm run console
npm run test
npm run lint
npm run security
```

Rails-native commands:

```bash
bundle install
bundle exec rails db:prepare
bundle exec rails server
bundle exec sidekiq -C config/sidekiq.yml
bundle exec rspec
bundle exec rubocop
bundle exec brakeman --no-pager -q
```

Required local services:

- PostgreSQL;
- Redis.

Important environment variables:

- `SHOPIFY_API_KEY`;
- `SHOPIFY_API_SECRET`;
- `SHOPIFY_APP_URL`;
- `DATABASE_URL`;
- `REDIS_URL`;
- `MAIL_FROM`;
- `SECRET_KEY_BASE`;
- `RAILS_MASTER_KEY`;
- `SENTRY_DSN`;
- `AI_PROVIDER`;
- `OPENAI_API_KEY`;
- `OPENAI_MODEL`;
- `OPENAI_BASE_URL`;
- `ANTHROPIC_API_KEY`;
- `ANTHROPIC_MODEL`;
- `ANTHROPIC_BASE_URL`.

## Repository Layout

```text
app/
  controllers/       Rails controllers for web, webhook, GDPR, and app flows
  models/            ActiveRecord domain models
  services/          Shopify, inventory, cache, agent, notification, and report logic
  jobs/              Sidekiq/ActiveJob background jobs
  mailers/           Alert and purchase order emails
  views/             ERB templates and partials
  assets/            CSS, images, and JavaScript

config/
  routes.rb          Application routes
  initializers/      Sidekiq, Redis, Rack::Attack, OmniAuth, CORS, Sentry, security headers
  environments/      Rails environment configuration

db/
  migrate/           Database migrations
  schema.rb          Current schema
  seeds.rb           Seed data

spec/
  factories/         FactoryBot factories
  models/            Model specs
  services/          Service specs
  jobs/              Job specs
  requests/          Request specs
  integration/       Multi-step pipeline specs
  security/          Security checks
  resilience/        Error handling specs
  concurrency/       Race condition and idempotency specs

docs/
  SECURITY_COMPLIANCE.md
  TESTING_CHECKLIST.md
  banner.png

test/e2e/
  Puppeteer-based browser scripts and generated screenshots

scripts/
  Capture, sync, CSS rebuild, and planning support scripts
```

## Current Implementation Gaps and Inconsistencies

The current codebase is functional in many areas, but several files suggest work that is either unfinished or out of sync with documentation:

- `AfterAuthenticateJob` exists but is not invoked from `ConnectionsController#shopify_callback`.
- `WeeklyReportJob` is scheduled in `config/initializers/sidekiq.rb`, but no `app/jobs/weekly_report_job.rb` exists.
- `Reports::WeeklyGenerator` exists, but the old `weekly_reports` table was dropped and there is no current report persistence model.
- `ReportMailer` is referenced in planning/testing docs but is not present.
- Security docs describe Shopify embedded iframe headers, while the current security initializer denies framing.
- Rate limiting attempts shop/user-based throttling, but current session storage may cause many rules to fall back to IP.
- The README and some docs still mention features or architecture decisions that appear to come from earlier implementation plans.

## Summary

StockPilot is a Rails-based Shopify inventory operations app. Its strongest implemented areas are Shopify data ingestion, inventory persistence, low-stock detection, alerting, tenant isolation, audit logging, background jobs, and the newer agent-run subsystem. The codebase also contains a polished server-rendered UI, a custom landing page, broad RSpec coverage, and CI security gates.

The main next step for production readiness is to reconcile the current implementation with the product claims: wire post-auth setup, resolve embedded-app security headers, finish or remove weekly report scheduling, and ensure throttling/authorization match the intended multi-tenant security model.
