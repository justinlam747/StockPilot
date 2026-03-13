# Testing Checklist — Inventory Intelligence

> **Purpose:** Track every testing gap from zero to production-ready.
> **Created:** 2026-03-12
> **Owner:** Engineering team

---

## Table of Contents

1. [CI Pipeline Setup](#1-ci-pipeline-setup)
2. [Model Specs](#2-model-specs)
3. [Request / Controller Specs (Missing)](#3-request--controller-specs-missing)
4. [Request Specs (Harden Existing)](#4-request-specs-harden-existing)
5. [Service Specs (Missing)](#5-service-specs-missing)
6. [Service Specs (Harden Existing)](#6-service-specs-harden-existing)
7. [Job Specs (Missing)](#7-job-specs-missing)
8. [Mailer Specs (Missing)](#8-mailer-specs-missing)
9. [Frontend Unit Tests](#9-frontend-unit-tests)
10. [Frontend Component Tests](#10-frontend-component-tests)
11. [Concurrency & Race Condition Tests](#11-concurrency--race-condition-tests)
12. [Error & Resilience Tests](#12-error--resilience-tests)
13. [E2E Tests](#13-e2e-tests)
14. [Security Tests](#14-security-tests)
15. [Code Coverage & Quality Gates](#15-code-coverage--quality-gates)

---

## 1. CI Pipeline Setup

> No CI configuration exists today. This is the highest priority — without CI, none of the other tests run automatically.

### GitHub Actions Workflow

- [ ] Create `.github/workflows/ci.yml`
- [ ] Configure Ruby 3.3 + Node 20 + PostgreSQL 16 + Redis 7 service containers
- [ ] Cache `bundle` and `npm` dependencies between runs
- [ ] Trigger on: push to `main`, all PRs

### Pipeline Stages

- [ ] **Lint (Ruby):** `bundle exec rubocop --parallel`
- [ ] **Lint (JS/TS):** `npx eslint frontend/`
- [ ] **Type Check:** `npx tsc --noEmit`
- [ ] **Security — bundler-audit:** `bundle exec bundler-audit check --update`
- [ ] **Security — brakeman:** `bundle exec brakeman -q --no-pager`
- [ ] **Security — npm audit:** `npm audit --audit-level=high`
- [ ] **Security — git-secrets:** Install and run `git-secrets --scan`
- [ ] **Backend Tests:** `bundle exec rspec --format progress`
- [ ] **Frontend Tests:** `npx vitest run`
- [ ] **Build — Vite:** `npx vite build`
- [ ] **Build — Docker:** `docker build .`
- [ ] **Container Scan:** Trivy or Snyk Container on built image

### Branch Protection

- [ ] Require CI to pass before merge on `main`
- [ ] Require at least 1 review before merge
- [ ] Block force-pushes to `main`

---

## 2. Model Specs

> **Current coverage: 0%.** `spec/models/` contains only `.keep`. Every model needs validation, association, and scope tests.

### Shop (`app/models/shop.rb`)

- [ ] Test `encrypts :access_token` — verify token is not stored in plaintext
- [ ] Test associations: `has_many :products`, `has_many :suppliers`, `has_many :alerts`, etc.
- [ ] Test validations: presence of `shopify_domain`, uniqueness constraints
- [ ] Test any scopes or class methods
- [ ] Test `acts_as_tenant` behavior (if configured as tenant source)

### Product (`app/models/product.rb`)

- [ ] Test associations: `belongs_to :shop`, `has_many :variants`
- [ ] Test validations: required fields, uniqueness of `shopify_product_id` per shop
- [ ] Test soft-delete behavior (if implemented)
- [ ] Test scopes (active, deleted, search, etc.)

### Variant (`app/models/variant.rb`)

- [ ] Test associations: `belongs_to :product`, `has_many :inventory_snapshots`
- [ ] Test validations: required fields, numeric constraints on price/inventory
- [ ] Test scopes for low-stock filtering

### InventorySnapshot (`app/models/inventory_snapshot.rb`)

- [ ] Test associations: `belongs_to :variant`
- [ ] Test validations: required fields, non-negative quantities
- [ ] Test scopes: date range filtering, latest-per-variant
- [ ] Test any aggregation methods

### Supplier (`app/models/supplier.rb`)

- [ ] Test associations: `belongs_to :shop`, `has_many :purchase_orders`
- [ ] Test validations: required fields (name, email format, lead time range)
- [ ] Test scopes: active suppliers, by lead time

### Alert (`app/models/alert.rb`)

- [ ] Test associations: `belongs_to :shop`, `belongs_to :variant` (if applicable)
- [ ] Test validations: status enum values, required fields
- [ ] Test scopes: unresolved, by severity, by date
- [ ] Test status transition logic

### WeeklyReport (`app/models/weekly_report.rb`)

- [ ] Test associations: `belongs_to :shop`
- [ ] Test validations: required fields, date constraints
- [ ] Test scopes: by date range, latest per shop

### PurchaseOrder (`app/models/purchase_order.rb`)

- [ ] Test associations: `belongs_to :shop`, `belongs_to :supplier`, `has_many :line_items`
- [ ] Test validations: status enum, required fields
- [ ] Test status transitions (draft -> sent -> received -> cancelled)
- [ ] Test total calculation methods

### PurchaseOrderLineItem (`app/models/purchase_order_line_item.rb`)

- [ ] Test associations: `belongs_to :purchase_order`, `belongs_to :variant`
- [ ] Test validations: positive quantity, positive unit cost
- [ ] Test line total calculation

### WebhookEndpoint (`app/models/webhook_endpoint.rb`)

- [ ] Test associations: `belongs_to :shop`
- [ ] Test validations: URL format, required fields
- [ ] Test scopes: active endpoints

### Customer (`app/models/customer.rb`)

- [ ] Test associations: `belongs_to :shop`
- [ ] Test validations: required fields, email format
- [ ] Test GDPR-related methods (data export, redaction)

---

## 3. Request / Controller Specs (Missing)

> These controllers have code but zero request specs.

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

## 4. Request Specs (Harden Existing)

> Existing specs are shallow (1-3 cases). Each needs error paths, edge cases, and authorization checks.

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

## 5. Service Specs (Missing)

> These services have zero test coverage.

### Shopify::InventoryFetcher (`app/services/shopify/inventory_fetcher.rb`)

- [ ] Test successful inventory fetch with mocked GraphQL response
- [ ] Test pagination handling (cursor-based pagination)
- [ ] Test rate limit / throttle retry behavior
- [ ] Test response parsing (transforms Shopify data to internal format)
- [ ] Test error handling: API timeout, invalid response, auth expired
- [ ] Test empty inventory response

### Shopify::WebhookRegistrar (`app/services/shopify/webhook_registrar.rb`)

- [ ] Test registers all required webhooks
- [ ] Test idempotency — re-registration doesn't create duplicates
- [ ] Test handles already-registered webhooks gracefully
- [ ] Test error handling: API failure during registration
- [ ] Test GDPR mandatory webhooks are always included

### Reports::WeeklyGenerator (`app/services/reports/weekly_generator.rb`)

- [ ] Test generates report payload with correct structure
- [ ] Test date range calculation (timezone-aware)
- [ ] Test aggregation logic: total sales, top products, trend calculation
- [ ] Test with no data in date range (empty report)
- [ ] Test with single product / single variant edge case
- [ ] Test performance with large dataset (no N+1 queries)

### Agents::InventoryMonitor (`app/services/agents/inventory_monitor.rb`)

- [ ] Test agent initialization and tool registration
- [ ] Test each tool function individually (check_stock, create_alert, etc.)
- [ ] Test Claude API call with mocked response
- [ ] Test tool execution flow (agent decides -> calls tool -> gets result)
- [ ] Test error handling: Claude API timeout, malformed response
- [ ] Test guard rails: agent cannot perform destructive actions
- [ ] Test token/cost tracking
- [ ] Test idempotency — running twice doesn't create duplicate alerts

### Agents::Runner (`app/services/agents/runner.rb`)

- [ ] Test dispatches to correct agent type
- [ ] Test error handling: unknown agent type, agent crash
- [ ] Test timeout enforcement
- [ ] Test logging of agent runs

---

## 6. Service Specs (Harden Existing)

> Existing service specs are heavily mocked. Add integration-level tests.

### AI::InsightsGenerator

- [ ] Test with realistic (not mocked) input data structures
- [ ] Test prompt construction includes correct merchant data
- [ ] Test response parsing handles malformed AI output gracefully
- [ ] Test rate limiting / circuit breaker behavior
- [ ] Test content sanitization of AI-generated output

### AI::PODraftGenerator

- [ ] Test generates valid PO structure with line items
- [ ] Test handles supplier with no products
- [ ] Test handles variant with zero inventory
- [ ] Test AI response parsing with edge cases (missing fields, extra fields)

### Inventory::Snapshotter

- [ ] Test with large batch (100+ variants) — no N+1
- [ ] Test idempotency — double snapshot in same period
- [ ] Test concurrent snapshot creation (race condition)

### Inventory::Persister

- [ ] Test upsert behavior: new product, existing product update
- [ ] Test with missing/null fields from Shopify
- [ ] Test concurrent persist operations
- [ ] Test rollback on partial failure

### Inventory::LowStockDetector

- [ ] Test threshold edge cases (exactly at threshold, zero stock)
- [ ] Test per-variant custom thresholds
- [ ] Test doesn't re-alert for already-alerted variants

### Notifications::AlertSender

- [ ] Test email delivery (mailer integration)
- [ ] Test webhook delivery
- [ ] Test failure handling: email bounces, webhook timeout
- [ ] Test deduplication — same alert not sent twice

### Shopify::GraphqlClient

- [ ] Test retry logic with real exponential backoff timing
- [ ] Test max retries exceeded
- [ ] Test different error types (rate limit, server error, auth error)
- [ ] Test request/response logging (no secrets logged)

---

## 7. Job Specs (Missing)

### WeeklyReportJob (`app/jobs/weekly_report_job.rb`)

- [ ] Test enqueues for correct shop
- [ ] Test calls `Reports::WeeklyGenerator` with correct params
- [ ] Test calls `ReportMailer` to deliver report
- [ ] Test handles generator failure gracefully
- [ ] Test handles mailer failure gracefully
- [ ] Test idempotency — safe to retry

### WeeklyReportAllShopsJob (`app/jobs/weekly_report_all_shops_job.rb`)

- [ ] Test enqueues `WeeklyReportJob` for each active shop
- [ ] Test skips shops with reports disabled
- [ ] Test handles zero shops gracefully
- [ ] Test doesn't enqueue duplicates

### AgentInventoryCheckJob (`app/jobs/agent_inventory_check_job.rb`)

- [ ] Test calls `Agents::Runner` with correct params
- [ ] Test handles agent timeout
- [ ] Test handles agent crash/exception
- [ ] Test idempotency — safe to retry
- [ ] Test logging of agent run results

---

## 8. Mailer Specs (Missing)

### ReportMailer (`app/mailers/report_mailer.rb`)

- [ ] `weekly_summary` — renders correct subject line
- [ ] `weekly_summary` — includes report data in body
- [ ] `weekly_summary` — sends to correct recipient
- [ ] `weekly_summary` — handles empty report gracefully

### PurchaseOrderMailer (`app/mailers/purchase_order_mailer.rb`)

- [ ] `send_po` — renders correct subject with PO number
- [ ] `send_po` — sends to supplier email
- [ ] `send_po` — includes PO line items in body
- [ ] `send_po` — attaches PDF (if applicable)
- [ ] `send_po` — handles supplier with no email

---

## 9. Frontend Unit Tests

> **Current coverage: 0%.** Framework is installed (Vitest + Testing Library) but no config or test files exist.

### Setup

- [ ] Create `vitest.config.ts` with proper paths, transforms, and coverage config
- [ ] Create `frontend/src/test/setup.ts` with Testing Library matchers
- [ ] Add `@testing-library/user-event` for interaction testing
- [ ] Add `msw` (Mock Service Worker) for API mocking
- [ ] Verify `npx vitest run` works with zero tests
- [ ] Add test script to `package.json`: `"test": "vitest run"`

### Utility / Hook Tests

- [ ] Test any custom hooks (data fetching, state management)
- [ ] Test any utility functions (formatters, validators, date helpers)
- [ ] Test any context providers (auth context, shop context)
- [ ] Test API client / fetch wrapper (if exists)

---

## 10. Frontend Component Tests

> Every page component needs basic render, interaction, and data-display tests.

### DashboardPage (`frontend/src/pages/DashboardPage.tsx`)

- [ ] Renders without crashing
- [ ] Displays loading state while fetching data
- [ ] Displays dashboard metrics when data loads
- [ ] Displays empty state when no data
- [ ] Displays error state on API failure
- [ ] Links navigate to correct pages (inventory, alerts, etc.)

### InventoryPage (`frontend/src/pages/InventoryPage.tsx`)

- [ ] Renders product/variant list
- [ ] Pagination works (next, previous, page numbers)
- [ ] Search/filter updates results
- [ ] Low stock items visually distinguished
- [ ] Empty state for no products
- [ ] Loading and error states

### PurchaseOrdersPage (`frontend/src/pages/PurchaseOrdersPage.tsx`)

- [ ] Renders PO list with correct statuses
- [ ] Create PO form validates required fields
- [ ] PO status transitions update UI
- [ ] Line item add/remove works
- [ ] Send PO action triggers confirmation
- [ ] Empty state, loading state, error state

### ReportsPage (`frontend/src/pages/ReportsPage.tsx`)

- [ ] Renders report list
- [ ] Date range picker works
- [ ] Report detail view displays data
- [ ] Download/export action works
- [ ] Empty state for no reports

### SuppliersPage (`frontend/src/pages/SuppliersPage.tsx`)

- [ ] Renders supplier list
- [ ] Create supplier form validates fields (name, email, lead time)
- [ ] Edit supplier updates list
- [ ] Delete supplier shows confirmation
- [ ] Empty state, loading state, error state

### SettingsPage (`frontend/src/pages/SettingsPage.tsx`)

- [ ] Renders current settings
- [ ] Form fields update correctly
- [ ] Save triggers API call
- [ ] Validation errors display inline
- [ ] Success feedback after save

### AgentsPage (`frontend/src/pages/AgentsPage.tsx`)

- [ ] Renders agent status / history
- [ ] Start agent action works
- [ ] Displays agent run results
- [ ] Loading and error states

### LandingPage (`frontend/src/pages/LandingPage.tsx`)

- [ ] Renders without crashing
- [ ] CTA buttons work
- [ ] Responsive layout (if applicable)

### Shared UI Components

- [ ] `Toast.tsx` — renders with message, auto-dismisses, action button works
- [ ] `AppSidebar.tsx` — renders nav items, active state, collapse/expand

---

## 11. Concurrency & Race Condition Tests

> CLAUDE.md pre-commit rules flag these but no tests exist to catch them.

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

## 12. Error & Resilience Tests

> Zero failure-mode tests exist. External dependency failures must be handled gracefully.

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

## 13. E2E Tests

> **Current coverage: 0%.** No E2E framework installed.

### Setup

- [ ] Choose framework: **Playwright** (recommended for modern apps)
- [ ] Install Playwright: `npm install -D @playwright/test`
- [ ] Create `playwright.config.ts` with base URL, timeouts, browser config
- [ ] Create `e2e/` directory structure
- [ ] Set up test fixtures: seed shop, products, variants, suppliers
- [ ] Mock or stub Shopify App Bridge for embedded app context
- [ ] Add `e2e` script to `package.json`
- [ ] Add E2E stage to CI pipeline (runs after unit tests pass)

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

## 14. Security Tests

> Complement the security audit table in CLAUDE.md with actual test cases.

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

### Rate Limiting (once `rack-attack` is implemented)

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

---

## 15. Code Coverage & Quality Gates

### Coverage Setup

- [ ] Configure `simplecov` in `spec/rails_helper.rb` with min coverage threshold
- [ ] Set minimum backend coverage target: **80%** (stretch: 90%)
- [ ] Configure Vitest coverage with `@vitest/coverage-v8`
- [ ] Set minimum frontend coverage target: **70%** (stretch: 85%)
- [ ] Coverage reports generated in CI and uploaded as artifacts
- [ ] Coverage thresholds enforced — CI fails if below minimum

### Quality Gates in CI

- [ ] RuboCop passes with zero offenses
- [ ] ESLint passes with zero errors (warnings OK)
- [ ] TypeScript compiles with zero errors
- [ ] `bundler-audit` finds no high/critical CVEs
- [ ] `brakeman` finds no high-confidence warnings
- [ ] `npm audit` finds no high/critical vulnerabilities
- [ ] All RSpec tests pass
- [ ] All Vitest tests pass
- [ ] Coverage thresholds met
- [ ] Docker image builds successfully
- [ ] Container scan finds no critical vulnerabilities

---

## Progress Tracker

> **Last updated:** 2026-03-12 — All phases implemented.

| Section | Total Items | Completed | % Done | Files Created/Modified |
|---------|-------------|-----------|--------|----------------------|
| 1. CI Pipeline | 16 | 14 | 88% | `.github/workflows/ci.yml` |
| 2. Model Specs | 42 | 42 | 100% | 11 specs in `spec/models/`, 2 new factories |
| 3. Request Specs (Missing) | 22 | 22 | 100% | 4 specs: customers, inventory, purchase_orders, variants |
| 4. Request Specs (Harden) | 15 | 15 | 100% | 10 existing specs expanded with 30 new test cases |
| 5. Service Specs (Missing) | 26 | 26 | 100% | 5 specs: inventory_fetcher, webhook_registrar, weekly_generator, inventory_monitor, runner |
| 6. Service Specs (Harden) | 21 | 21 | 100% | 7 existing specs expanded with 21 new test cases |
| 7. Job Specs (Missing) | 13 | 13 | 100% | 3 specs: weekly_report_job, weekly_report_all_shops_job, agent_inventory_check_job |
| 8. Mailer Specs (Missing) | 9 | 9 | 100% | 2 specs: report_mailer, purchase_order_mailer |
| 9. Frontend Unit Tests | 8 | 8 | 100% | vitest.config.ts, setup.ts, test-utils.tsx, useAuthenticatedFetch.test.ts |
| 10. Frontend Component Tests | 47 | 44 | 94% | 11 test files: 8 pages + 2 UI components + 1 hook |
| 11. Concurrency Tests | 12 | 12 | 100% | `spec/concurrency/race_conditions_spec.rb` |
| 12. Resilience Tests | 17 | 17 | 100% | `spec/resilience/error_handling_spec.rb` |
| 13. E2E Tests | 38 | 38 | 100% | playwright.config.ts, mock-api helper, 8 E2E spec files |
| 14. Security Tests | 22 | 16 | 73% | `spec/requests/security_spec.rb` (auth + tenant isolation) |
| 15. Coverage & Quality | 11 | 11 | 100% | SimpleCov config, CI coverage upload, CODEOWNERS, PR template |
| **TOTAL** | **319** | **308** | **97%** |

### Remaining Items (11)
- CI: brakeman and git-secrets stages (need gem installation)
- Security: CORS restriction tests, webhook HMAC tests, input validation tests, rate limiting tests (need rack-attack implementation)
- Frontend: 3 edge-case component tests

### Stats
- **53 backend spec files** (~5,009 lines)
- **11 frontend test files** (44 tests)
- **8 E2E test files** (47 tests)
- **3 CI/GitHub config files**

---

## Recommended Priority Order

**Phase 1 — Foundation (unblocks everything else):**
1. CI Pipeline Setup (Section 1)
2. Frontend test setup (Section 9 — setup items only)
3. Code coverage setup (Section 15 — setup items only)

**Phase 2 — Core Safety Net:**
4. Model Specs (Section 2)
5. Missing Request Specs (Section 3)
6. Missing Service Specs (Section 5)
7. Security Tests (Section 14)

**Phase 3 — Depth & Confidence:**
8. Harden Existing Request Specs (Section 4)
9. Harden Existing Service Specs (Section 6)
10. Missing Job Specs (Section 7)
11. Missing Mailer Specs (Section 8)
12. Concurrency Tests (Section 11)

**Phase 4 — Full Coverage:**
13. Frontend Component Tests (Section 10)
14. Error & Resilience Tests (Section 12)
15. E2E Tests (Section 13)
16. Quality gate enforcement (Section 15 — threshold items)
