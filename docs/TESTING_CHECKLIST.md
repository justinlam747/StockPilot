# Testing Checklist — Inventory Intelligence

> **Purpose:** Track every testing gap from zero to production-ready.
> **Created:** 2026-03-12
> **Owner:** Engineering team

---

## Local Rails checks

Run `bundle exec rspec` to exercise the request, integration, concurrency, resilience and security specs. Browser workflows live in `test/e2e/`.

## Request and controller scenarios

### CustomersController (`api/v1/customers_controller.rb`)

- [ ] `GET /api/v1/customers` — returns paginated customer list
- [ ] `GET /api/v1/customers` — respects tenant isolation (shop-scoped)
- [ ] `GET /api/v1/customers/:id` — returns single customer
- [ ] `GET /api/v1/customers/:id` — returns 404 for other shop's customer
- [ ] Test strong parameters on any write endpoints
- [ ] Test authentication required (401 without session)

### InventoryController (`api/v1/inventory_controller.rb`)

- [ ] `GET /api/v1/inventory` — returns current inventory levels
- [ ] `GET /api/v1/inventory` — supports pagination
- [ ] `GET /api/v1/inventory` — filters by product/variant
- [ ] `GET /api/v1/inventory` — scoped to current shop only
- [ ] `POST /api/v1/inventory/sync` — triggers inventory sync (if exists)
- [ ] Test authentication required

### PurchaseOrdersController (`api/v1/purchase_orders_controller.rb`)

- [ ] `GET /api/v1/purchase_orders` — returns paginated PO list
- [ ] `GET /api/v1/purchase_orders/:id` — returns PO with line items
- [ ] `POST /api/v1/purchase_orders` — creates PO with valid params
- [ ] `POST /api/v1/purchase_orders` — rejects invalid params (422)
- [ ] `PATCH /api/v1/purchase_orders/:id` — updates PO status
- [ ] `PATCH /api/v1/purchase_orders/:id` — rejects invalid status transitions
- [ ] `DELETE /api/v1/purchase_orders/:id` — soft-deletes or cancels PO
- [ ] `POST /api/v1/purchase_orders/:id/send` — sends PO to supplier (if exists)
- [ ] Test tenant isolation on all endpoints
- [ ] Test strong parameters
- [ ] Test authentication required

### VariantsController (`api/v1/variants_controller.rb`)

- [ ] `GET /api/v1/variants` — returns paginated variant list
- [ ] `GET /api/v1/variants` — supports filtering (low stock, by product)
- [ ] `GET /api/v1/variants/:id` — returns variant with inventory history
- [ ] Test tenant isolation
- [ ] Test authentication required

---

## Request hardening

### All Existing Request Specs

- [ ] **Suppliers:** Add 422 for invalid create/update, 404 for wrong shop, duplicate name handling
- [ ] **Products:** Add search/filter tests, empty result set, invalid pagination params
- [ ] **Alerts:** Add filtering by status/severity, bulk update, alert for nonexistent variant
- [ ] **Reports:** Add date range validation, empty report handling, timezone edge cases
- [ ] **Settings:** Add invalid setting values, partial update, reset to defaults
- [ ] **Shops:** Add unauthorized access attempts, shop not found
- [ ] **AI Insights:** Add rate limit behavior, API timeout handling, invalid input
- [ ] **Webhook Endpoints:** Add invalid URL format, duplicate endpoint, delivery failure
- [ ] **Webhooks (app_uninstalled):** Add invalid HMAC, replay attack (duplicate delivery)
- [ ] **GDPR:** Add actual data processing verification (currently returns 200 without action)
- [ ] **Health:** Add degraded state (Redis down, DB down)

### Cross-Cutting Concerns (All Endpoints)

- [ ] Every endpoint returns 401 without valid session token
- [ ] Every endpoint returns 403 for wrong shop's resources
- [ ] Every list endpoint is paginated (no unbounded queries)
- [ ] Every write endpoint validates strong parameters
- [ ] Every endpoint returns proper error format (JSON API errors)

---

## Concurrency and race conditions

### Database-Level Concurrency

- [ ] Two `InventorySyncJob`s for the same shop — verify no duplicate snapshots
- [ ] `find_or_create_by` calls — verify unique index prevents duplicates under concurrency
- [ ] Counter updates use `UPDATE SET count = count + 1` (atomic), not read-modify-write
- [ ] `Inventory::Persister` upsert — two concurrent upserts for same product don't corrupt data

### Advisory Lock / Row Lock Tests

- [ ] `with_lock` is used where needed — test that concurrent operations serialize correctly
- [ ] Advisory locks on shop-level operations prevent overlapping syncs

### Sidekiq Concurrency

- [ ] Duplicate job detection — same job enqueued twice produces correct result (idempotent)
- [ ] Job uniqueness — `WeeklyReportJob` for same shop doesn't run in parallel
- [ ] Failed job retry — retrying a partially completed job doesn't create duplicates

### Alert Deduplication

- [ ] Same low-stock condition detected twice in one run — only one alert created
- [ ] Alert resolved then re-triggered — new alert created (not a duplicate)

---

## Error handling and resilience

### Shopify API Failures

- [ ] API returns 429 (rate limited) — retry with backoff
- [ ] API returns 500 — retry then fail gracefully
- [ ] API returns 401 (token expired) — surface auth error, don't retry forever
- [ ] API timeout — fail within reasonable time, log error
- [ ] API returns malformed JSON — handle parse error

### Anthropic (Claude) API Failures

- [ ] API returns 429 — respect rate limit, backoff
- [ ] API returns 500 — circuit breaker trips after N failures
- [ ] API timeout — fail gracefully, return fallback message
- [ ] API returns unexpected format — sanitize and handle
- [ ] API key invalid — clear error message, don't retry

### Redis Failures

- [ ] Redis connection lost — Sidekiq jobs queued, app still serves requests
- [ ] Redis returns to healthy — jobs resume automatically
- [ ] Redis memory full — app behavior is predictable (not silent data loss)

### PostgreSQL Failures

- [ ] Database connection pool exhausted — clear error, no hung requests
- [ ] Transaction deadlock — retry or fail with useful error
- [ ] Migration lock timeout — doesn't block app indefinitely

### Email Delivery Failures

- [ ] SMTP server down — job retries, doesn't crash
- [ ] Invalid recipient — logged, doesn't block other emails
- [ ] Rate limited by SendGrid — backoff and retry

---

## End-to-end checks

### Critical User Journeys

#### Merchant Onboarding Flow

- [ ] App loads in Shopify Admin iframe
- [ ] OAuth flow completes (session established)
- [ ] Initial inventory sync triggers automatically
- [ ] Dashboard shows synced data

#### Inventory Monitoring Flow

- [ ] Dashboard displays current stock levels
- [ ] Navigate to Inventory page
- [ ] Search for a product by name
- [ ] Filter by low-stock status
- [ ] View variant detail with inventory history chart

#### Low-Stock Alert Flow

- [ ] Low-stock variant triggers alert
- [ ] Alert appears on Dashboard
- [ ] Alert notification email received (mock SMTP)
- [ ] Merchant resolves alert from UI
- [ ] Alert status updates to resolved

#### Purchase Order Flow

- [ ] Navigate to Purchase Orders page
- [ ] Click "Create PO" button
- [ ] Select supplier from dropdown
- [ ] Add line items (variants + quantities)
- [ ] Save draft PO
- [ ] Send PO to supplier (email triggered)
- [ ] PO status updates to "sent"

#### Supplier Management Flow

- [ ] Navigate to Suppliers page
- [ ] Create new supplier with all fields
- [ ] Validation errors show for invalid input
- [ ] Edit existing supplier
- [ ] Delete supplier with confirmation

#### Reports Flow

- [ ] Navigate to Reports page
- [ ] View latest weekly report
- [ ] Report displays correct metrics
- [ ] Date range filter works

#### Settings Flow

- [ ] Navigate to Settings page
- [ ] Update low-stock threshold
- [ ] Update notification preferences
- [ ] Save settings
- [ ] Settings persist after page reload

#### AI Insights Flow

- [ ] Request AI insights from Dashboard
- [ ] Loading state displays while generating
- [ ] Insights render with recommendations
- [ ] Insights are sanitized (no raw HTML injection)

#### GDPR Compliance Flow

- [ ] `customers/data_request` webhook → data export generated
- [ ] `customers/redact` webhook → customer data deleted
- [ ] `shop/redact` webhook → all shop data deleted after uninstall

---

## Security checks

### Authentication

- [ ] All `/api/v1/*` endpoints return 401 without session token
- [ ] Expired session token returns 401
- [ ] Tampered session token returns 401
- [ ] Session token from Shop A cannot access Shop B data

### Tenant Isolation

- [ ] Query for Shop A's products with Shop B's session returns empty / 403
- [ ] Direct ID access to other shop's resources returns 404 / 403
- [ ] No endpoint leaks cross-tenant data in list responses

### CORS

- [ ] `OPTIONS` preflight from `https://admin.shopify.com` returns correct headers
- [ ] `OPTIONS` preflight from unknown origin is rejected
- [ ] `origins "*"` is removed (currently a known CRITICAL issue)

### Webhook Security

- [ ] Valid HMAC → 200
- [ ] Invalid HMAC → 401
- [ ] Missing HMAC header → 401
- [ ] Replay with old HMAC → 401

### Input Validation

- [ ] SQL injection attempt in search param → safe (parameterized query)
- [ ] XSS payload in supplier name → sanitized on render
- [ ] Oversized request body → 413 or 422
- [ ] Unexpected content type → 415 or 422

### Rate Limiting

- [ ] 61st request in 1 minute → 429
- [ ] AI endpoint: 11th request in 1 minute → 429
- [ ] Rate limit headers present (X-RateLimit-*)
- [ ] Rate limit resets after window

### Security Headers

- [ ] `Strict-Transport-Security` header present
- [ ] `X-Content-Type-Options: nosniff` present
- [ ] `Content-Security-Policy` restricts frame-ancestors to Shopify
- [ ] `Referrer-Policy` present
- [ ] `Permissions-Policy` disables camera/microphone/geolocation
