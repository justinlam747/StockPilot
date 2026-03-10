# GSD Plan — MVP Build Checklist

> **For:** Ralph
> **Goal:** Working MVP — iterate through each phase, check items off, don't skip ahead.
> **Rule:** Each phase must be fully green before starting the next. No design work — infrastructure only.

---

## Phase 0 — Project Boots (Days 1–2)

Get the app running locally in Docker. Nothing else.

- [ ] Copy `.env.example` → `.env`, fill in placeholder values for local dev
- [ ] `docker compose up db redis` — verify Postgres and Redis are healthy
- [ ] `docker compose build web` — verify the Docker image builds (Gemfile installs, npm installs, vite builds)
- [ ] `docker compose up` — verify Rails starts on `localhost:3000`
- [ ] Hit `GET /health` — should return `{ "status": "ok" }`
- [ ] Verify `docker compose up worker` — Sidekiq starts and connects to Redis
- [ ] Run migrations inside the container: `docker compose exec web bundle exec rails db:migrate`
- [ ] Verify all 11 tables exist: `docker compose exec db psql -U postgres -d shopify_inventory_development -c "\dt"`
- [ ] `docker compose exec web bundle exec rspec` — should run 0 tests, 0 failures (no specs written yet)

**Done when:** `docker compose up` starts web + worker + db + redis, `/health` returns 200, all tables exist.

---

## Phase 1 — Auth + Shopify Connection (Days 3–6)

Wire up Shopify OAuth so a dev store can install the app.

- [ ] Register app in Shopify Partner Dashboard
- [ ] Set App URL to your ngrok/cloudflare tunnel URL
- [ ] Set Redirect URL to `{tunnel_url}/auth/shopify/callback`
- [ ] Fill real `SHOPIFY_API_KEY` and `SHOPIFY_API_SECRET` in `.env`
- [ ] Update `SHOPIFY_APP_URL` in `.env` to match tunnel URL
- [ ] Verify `shopify_app` gem initializer loads without errors (check Rails console)
- [ ] Install app on a dev store — should redirect through OAuth and land back at the app
- [ ] Verify `shops` table has a row with your dev store's domain
- [ ] Verify `access_token` column is encrypted (raw DB value is not a readable `shpat_` token)
- [ ] Implement `AuthenticatedController#set_tenant` — verify it rejects requests without a valid session token
- [ ] Implement `AfterAuthenticateJob#perform` — register webhooks + trigger initial sync
- [ ] Verify webhooks are registered on the dev store (check Partner Dashboard → Webhooks)
- [ ] Send a test webhook from Partner Dashboard → verify `WebhooksController#receive` responds 200
- [ ] Verify HMAC verification rejects a webhook with a tampered signature (should get 401)
- [ ] Implement `GdprController` handlers — `customers_data_request`, `customers_redact`, `shop_redact`
- [ ] Test `shop/redact` — uninstall app, wait for webhook, verify shop record is destroyed

**Done when:** App installs on dev store, session token auth works, webhooks verified, GDPR endpoints respond.

---

## Phase 2 — Inventory Sync Pipeline (Days 7–12)

Fetch real products from Shopify and store them locally.

- [ ] Implement `Shopify::GraphqlClient#query` — single GraphQL call with error handling
- [ ] Implement `Shopify::GraphqlClient#paginate` — cursor-based pagination through connections
- [ ] Write a spec: `GraphqlClient` retries on `THROTTLED` error with backoff
- [ ] Implement `Shopify::InventoryFetcher#call` — fetch products + variants + inventory levels in one paginated query
- [ ] Test against dev store: run `InventoryFetcher` in Rails console, verify it returns product data
- [ ] Implement `Inventory::Persister#upsert` — upsert products and variants from GraphQL response
- [ ] Implement `Inventory::Persister#upsert_single_product` — upsert from webhook payload (REST format)
- [ ] Write a spec: `Persister` creates new products and updates existing ones (no duplicates)
- [ ] Implement `Inventory::Snapshotter#snapshot` — bulk insert snapshot rows from GraphQL response
- [ ] Write a spec: `Snapshotter` creates one snapshot row per variant
- [ ] Implement `InventorySyncJob#perform` — orchestrate fetch → persist → snapshot → detect → alert
- [ ] Implement `DailySyncAllShopsJob#perform` — enqueue one `InventorySyncJob` per active shop
- [ ] Test full sync: trigger `InventorySyncJob` from Rails console, verify products/variants/snapshots in DB
- [ ] Verify `shop.synced_at` is updated after successful sync
- [ ] Implement `SnapshotCleanupJob#perform` — delete snapshots older than 90 days in batches
- [ ] Write a spec: cleanup job deletes old snapshots, keeps recent ones
- [ ] Implement `WebhooksController#handle_products_update` — upsert product on webhook
- [ ] Implement `WebhooksController#handle_products_delete` — soft-delete product on webhook
- [ ] Test: update a product in Shopify admin → verify local DB updates via webhook
- [ ] Test: delete a product in Shopify admin → verify `deleted_at` is set
- [ ] Implement `Api::V1::ProductsController#index` — paginated, filterable
- [ ] Implement `Api::V1::ProductsController#show`
- [ ] Write request specs for products endpoints

**Done when:** Full sync runs, products/variants/snapshots in DB, webhooks update data, API returns paginated products.

---

## Phase 3 — Low Stock Detection + Alerts (Days 13–16)

Detect low stock and send email alerts.

- [ ] Implement `Inventory::LowStockDetector#detect` — subquery-based, no N+1
- [ ] Write specs: flags low stock, flags out of stock, respects variant-level threshold override, respects shop-level default
- [ ] Implement `Notifications::AlertSender#send_low_stock_alerts` — create alert records, fire emails, fire webhooks
- [ ] Write spec: does not double-alert same variant on same day
- [ ] Implement `AlertMailer.low_stock` — SendGrid email with list of low-stock variants
- [ ] Configure SendGrid in development (or use letter_opener for local testing)
- [ ] Wire `LowStockDetector` + `AlertSender` into `InventorySyncJob` (already stubbed)
- [ ] Test end-to-end: manually set a variant's stock below threshold in Shopify → trigger sync → verify alert created + email sent
- [ ] Implement `Api::V1::AlertsController#index` — paginated list of alerts for current shop
- [ ] Implement `Api::V1::AlertsController#update` — mark alert as acknowledged
- [ ] Implement `Api::V1::SettingsController#show` and `#update` — threshold, alert email, timezone
- [ ] Write request specs for alerts and settings endpoints

**Done when:** Sync detects low stock → alert record created → email sent → no duplicates within same day.

---

## Phase 4 — Weekly Reports (Days 17–21)

Auto-generate and email weekly inventory summaries.

- [ ] Implement `Reports::WeeklyGenerator#generate` — top sellers, stockouts, low stock count, reorder suggestions
- [ ] Write specs for each metric method in `WeeklyGenerator`
- [ ] Implement `WeeklyReportJob#perform` — generate report, save to DB, email
- [ ] Implement `WeeklyReportAllShopsJob#perform` — timezone-aware scheduling (check each shop's timezone, only enqueue if it's the right day + hour)
- [ ] Write spec: `WeeklyReportAllShopsJob` only enqueues for shops where it's Monday 8am in their timezone
- [ ] Write spec: idempotent — skips if report already exists for that week
- [ ] Implement `ReportMailer.weekly_summary` — formatted email with report data
- [ ] Verify Sidekiq cron job fires `WeeklyReportAllShopsJob` hourly (check Sidekiq web UI)
- [ ] Implement `Api::V1::ReportsController#index` — paginated list of reports
- [ ] Implement `Api::V1::ReportsController#show` — single report with payload
- [ ] Implement `Api::V1::ReportsController#generate` — manually trigger report generation
- [ ] Write request specs for reports endpoints

**Done when:** Reports auto-generate on schedule in shop's timezone, are emailed, and viewable via API.

---

## Phase 5 — Suppliers + Purchase Orders (Days 22–27)

CRUD for suppliers, generate PO drafts, send emails.

- [ ] Implement `Api::V1::SuppliersController` — full CRUD with strong params
- [ ] Write request specs for suppliers CRUD
- [ ] Implement `Api::V1::PurchaseOrdersController#create` — create PO with nested line items
- [ ] Implement `Api::V1::PurchaseOrdersController#generate_draft` — auto-fill line items from low-stock variants for a given supplier
- [ ] Implement `Api::V1::PurchaseOrdersController#send_email` — send PO to supplier via email
- [ ] Implement a basic rule-based PO email template (plain text, no AI yet)
- [ ] Write request specs for PO endpoints
- [ ] Test end-to-end: create supplier → assign variants → generate draft PO → send email

**Done when:** Suppliers CRUD works, PO draft auto-populates from low-stock data, email sends to supplier.

---

## Phase 6 — Outgoing Webhooks (Days 28–30)

Let merchants register webhook URLs to receive events.

- [ ] Implement `Api::V1::WebhookEndpointsController` — full CRUD with strong params
- [ ] Implement `WebhookDeliveryJob#perform` — POST to endpoint URL with retry
- [ ] Write spec: retries on timeout, records last status code
- [ ] Wire webhook firing into `AlertSender` (already stubbed)
- [ ] Write request specs for webhook endpoints CRUD
- [ ] Test end-to-end: register a webhook URL → trigger low stock → verify POST received

**Done when:** Merchants can register webhook URLs, events fire on low stock, retries work.

---

## Phase 7 — AI Layer (Days 31–35)

Add Claude-powered insights and PO drafts.

- [ ] Implement `AI::InsightsGenerator#generate` — build metrics, call Claude API, return bullets
- [ ] Implement error fallback — return "AI insights temporarily unavailable" on API failure
- [ ] Write spec: handles `Anthropic::Error` gracefully
- [ ] Implement `AI::PoDraftGenerator#generate` — call Claude API for PO email body
- [ ] Implement fallback plain-text template when Claude API is down
- [ ] Write spec: falls back to template on API failure
- [ ] Wire `InsightsGenerator` into `WeeklyReportJob` — store in `payload['ai_commentary']`
- [ ] Wire `PoDraftGenerator` into PO draft generation endpoint
- [ ] Implement `Api::V1::AiController#insights` — on-demand insights for dashboard
- [ ] Write request spec for AI insights endpoint

**Done when:** AI generates insights for reports + dashboard, PO drafts are AI-written, failures fall back gracefully.

---

## Phase 8 — Frontend Shell (Days 36–38)

Build the React pages that consume the API. Infrastructure only — make them functional, not pretty.

- [ ] Verify Vite Ruby serves the frontend at `localhost:3000` (Rails serves the HTML)
- [ ] `DashboardPage` — fetch `/api/v1/shop`, display summary cards + sync button + low stock table
- [ ] `InventoryPage` — fetch `/api/v1/products?page=1`, display paginated table with filter (all/low/out)
- [ ] `ReportsPage` — fetch `/api/v1/reports`, display list, click to show detail
- [ ] `SuppliersPage` — fetch `/api/v1/suppliers`, display list, add/edit modal
- [ ] `PurchaseOrdersPage` — generate draft flow, preview email, send button
- [ ] `SettingsPage` — threshold, email, timezone, webhook endpoints CRUD
- [ ] Verify `useAuthenticatedFetch` sends session token in `Authorization` header
- [ ] Verify `<ui-nav-menu>` navigation works inside Shopify admin iframe
- [ ] All pages use Polaris components only — follow the white/grey design rules from CLAUDE.md

**Done when:** All 6 pages render real data from the API, navigation works inside Shopify admin.

---

## Phase 9 — Hardening (Days 39–42)

Lock down security, fix the TODOs from CLAUDE.md security audit.

- [ ] Fix CORS — restrict to app domain + `https://admin.shopify.com`
- [ ] Add `rack-attack` rate limiting (60 req/min general, 10 req/min AI)
- [ ] Add security headers (CSP, HSTS, X-Content-Type-Options) — see CLAUDE.md §6f
- [ ] Add strong params to every controller action that accepts input
- [ ] Implement full GDPR data processing (not just 200 OK) — export customer data, delete on redact
- [ ] Add `brakeman` to CI
- [ ] Add `bundle-audit` to CI
- [ ] Add `npm audit` to CI
- [ ] Run full `/review` on entire codebase — race conditions, duplication, vulnerabilities
- [ ] Fix everything flagged

**Done when:** Security audit table in CLAUDE.md shows all items as "Done". Full review passes clean.

---

## Notes for Ralph

- **Don't skip phases.** Each phase builds on the last. Phase 2 needs Phase 1's auth. Phase 3 needs Phase 2's data.
- **Write specs as you go.** Don't save testing for the end. Each checklist item that says "write spec" is not optional.
- **Run `/review` before every commit.** Check for race conditions, duplication, and vulnerabilities. This is in CLAUDE.md and it's a hard requirement.
- **Check the spec.** `shopify-inventory-spec.md` has the complete implementation code for every service, job, and controller. Use it as reference — the code samples are designed to be copy-paste-able.
- **Don't do design.** Use Polaris defaults with the white/grey palette from CLAUDE.md. No custom CSS. Make it functional first.
