<p align="center">
  <img src="docs/banner.png" alt="StockPilot — Inventory intelligence for Shopify" width="1700">
</p>

# StockPilot

An embedded Shopify app that gives merchants real-time inventory intelligence — low-stock alerts, purchase order drafts, supplier management, and snapshot history.


## Tech Stack

| Layer | Technology |
|-------|-----------|
| Backend | Ruby on Rails 7.2 |
| Database | PostgreSQL 16 |
| Background Jobs | Sidekiq 7 + Redis 7 |
| Auth | OmniAuth + Shopify OAuth |
| Multi-tenancy | acts_as_tenant (shop-scoped data isolation) |
| Security | Rack::Attack, Brakeman, bundler-audit, HMAC webhook verification |
| Monitoring | Sentry (Rails + Sidekiq) |
| CI | GitHub Actions (RuboCop, Brakeman, bundler-audit, RSpec + Postgres/Redis services) |

## Features

- **Inventory Sync** — Pulls product and variant data from Shopify's GraphQL Admin API, snapshots stock levels over time
- **Low-Stock Alerts** — Configurable per-variant thresholds with email notifications when stock drops below target
- **Purchase Orders** — Draft purchase orders generated from low-stock signals, sent to suppliers via email
- **Supplier Management** — Track suppliers, contacts, lead times, and star ratings; link suppliers to variants
- **GDPR Compliance** — Handles `customers/data_request`, `customers/redact`, and `shop/redact` webhooks with full data processing
- **Audit Logging** — Tracks all security-relevant events (auth, data exports, GDPR requests) with request metadata

## Architecture

```
Shopify Admin (OAuth session)
        │
        ▼
┌─────────────────────────────────────────────┐
│  Rails 7.2 (embedded app)                   │
│                                             │
│  Auth ──── Inventory Sync ──── Alerts       │
│  OAuth     GraphQL + Webhooks  Email notifs │
│                                             │
│  Supplier Mgmt ──── Purchase Orders         │
│  CRUD + ratings     Draft + send flow       │
│                                             │
│  Security: Rack::Attack, HMAC, CSP, HSTS    │
│  Multi-tenancy: acts_as_tenant :shop        │
└──────────┬──────────────┬───────────────────┘
           │              │
     PostgreSQL 16    Sidekiq + Redis 7
```

## Security

- **Webhook HMAC-SHA256 verification** on all inbound Shopify webhooks
- **Rate limiting** via Rack::Attack — 60 req/min general, 100 req/min webhooks
- **Encrypted access tokens** at rest using Rails 7.2 `encrypts`
- **Security headers** — HSTS, CSP (frame-ancestors restricted to Shopify), X-Content-Type-Options, Referrer-Policy
- **Static analysis** — Brakeman runs in CI; bundler-audit checks gems for CVEs
- **Tenant isolation** — All queries scoped via `acts_as_tenant`, no cross-merchant data leakage
- **CORS** restricted to app domain + `admin.shopify.com`

## Database

`Shop` → `Product` → `Variant` → `InventorySnapshot`
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;→ `Alert`
`Shop` → `Supplier` → `PurchaseOrder` → `PurchaseOrderLineItem`
`Shop` → `AuditLog`

## Background Jobs

| Job | Purpose |
|-----|---------|
| `InventorySyncJob` | Fetches latest stock levels from Shopify GraphQL API |
| `DailySyncAllShopsJob` | Triggers sync across all installed shops |
| `SnapshotCleanupJob` | Prunes old inventory snapshots |
| `GdprCustomerDataJob` | Processes customer data export requests |
| `GdprCustomerRedactJob` | Redacts customer data on request |
| `GdprShopRedactJob` | Cleans up all shop data after uninstall |
| `AfterAuthenticateJob` | Post-OAuth: registers webhooks + triggers initial sync |

## Running Locally

Prerequisites: PostgreSQL 16 and Redis 7.

```bash
bundle install
bundle exec rails db:prepare
bundle exec rails server
bundle exec sidekiq -C config/sidekiq.yml   # separate terminal

# Tests
bundle exec rspec

# Lint + security
bundle exec rubocop
bundle exec brakeman
bundle exec bundler-audit check --update
```

## Environment Variables

See `.env.example` for the full list. Key variables:

- `SHOPIFY_API_KEY` / `SHOPIFY_API_SECRET`
- `SHOPIFY_APP_URL`
- `DATABASE_URL`
- `REDIS_URL`
- `SENTRY_DSN` (optional)
