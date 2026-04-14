# Testing Checklist - Catalog Audit

> Purpose: track the current testing gaps for the lean Catalog Audit product.
>
> This checklist replaces the old inventory-era matrix. The active product is now
> connect -> sync -> audit -> review.

---

## 1. CI And Baseline Safety

- [ ] Keep `bundle exec rubocop` in CI and locally before merge.
- [ ] Keep `bundle exec rspec` in CI and locally before merge.
- [ ] Keep `bundle exec bundler-audit check --update` in CI.
- [ ] Keep `bundle exec brakeman -q --no-pager` in CI.
- [ ] Fail the pipeline if any security gate regresses.
- [ ] Document any new CI stage in `CLAUDE.md` before merge.

---

## 2. Request Specs - Current Public Flow

### Landing And Connection

- [ ] `GET /` renders the Catalog Audit landing page.
- [ ] `POST /connections/shopify` normalizes `store-name` into a Shopify domain.
- [ ] `POST /connections/shopify` rejects blank input with a helpful error.
- [ ] `GET /auth/shopify/callback` stores the connected shop and redirects to the dashboard.
- [ ] `GET /auth/failure` returns the user to settings with an error message.
- [ ] `DELETE /connections/shopify/:id` disconnects the shop and clears the session shop.

### Dashboard

- [ ] `GET /dashboard` renders summary counts from the audit service.
- [ ] `POST /sync` triggers the sync path for the current shop.
- [ ] Dashboard does not expose old inventory, supplier, or purchase-order language.

### Issues

- [ ] `GET /issues` renders the issue list.
- [ ] `GET /issues` filters by severity.
- [ ] `GET /issues` supports search by title or SKU.
- [ ] `GET /issues` paginates or chunks results if the list grows.
- [ ] Each issue row links to the correct Shopify Admin product URL.

### Settings

- [ ] `GET /settings` shows the no-store-connected state.
- [ ] `GET /settings` shows the connected-store state.
- [ ] `PATCH /settings` validates the submitted shop settings.
- [ ] Settings updates stay limited to the lean product needs.

### Health, Webhooks, GDPR

- [ ] `GET /health` returns OK for the current stack.
- [ ] Shopify webhooks reject invalid HMAC signatures.
- [ ] `POST /gdpr/shop_redact` deletes shop-scoped data that the app stores.
- [ ] `POST /gdpr/customers_data_request` and `POST /gdpr/customers_redact` return the expected compliance responses.

---

## 3. Service Specs - Active Product Logic

### Catalog Audit Service

- [ ] Computes summary counts from current product and variant data.
- [ ] Detects duplicate SKU issues.
- [ ] Detects missing SKU issues.
- [ ] Detects missing or zero price issues.
- [ ] Detects missing product image issues.
- [ ] Detects blank vendor issues.
- [ ] Detects blank product type issues.
- [ ] Detects weak-title issues using the current rule.
- [ ] Produces deterministic ordering for the same input set.
- [ ] Produces stable fingerprints for issue deduping.

### Shopify Integration

- [ ] Shopify GraphQL client handles success and retry behavior.
- [ ] Shopify catalog fetcher requests only fields needed by the audit rules.
- [ ] Shopify sync/persister path is idempotent.
- [ ] Webhook registration only includes topics the lean product still uses.
- [ ] Webhook-triggered refreshes do not do heavy work inline.

### Utility Services

- [ ] Any helper that normalizes shop domains has edge-case coverage.
- [ ] Any helper that builds Shopify Admin URLs handles missing product IDs safely.

---

## 4. Job Specs - Minimal Async Flow

- [ ] Sync job enqueues or runs once per shop without duplication.
- [ ] Sync job updates `synced_at` when it succeeds.
- [ ] Sync job is safe to retry.
- [ ] Sync job failure leaves useful logs and no partial corruption.
- [ ] Any webhook-triggered refresh job is idempotent.

If old inventory-era jobs remain temporarily, they should have tests only until they are deleted, then the specs should be removed with the code.

---

## 5. Model Specs - Current Data Model

### Keep And Verify

- [ ] `Shop` encrypts access tokens.
- [ ] `Shop` stays shop-scoped.
- [ ] `Product` belongs to a shop and has the fields the audit service needs.
- [ ] `Variant` belongs to a product and has the fields the audit service needs.

### Cleanup Targets

- [ ] Delete specs for models that no longer belong to the lean product path.
- [ ] Remove assertions that encode old inventory or supplier behavior.

---

## 6. Controller And UI Specs

- [ ] Dashboard spec verifies audit summary values match the audit service.
- [ ] Issues page spec verifies filter and search behavior.
- [ ] Settings spec verifies connected and disconnected states.
- [ ] Landing spec verifies the Catalog Audit message and CTA.
- [ ] Sidebar spec verifies only dashboard, issues, and settings are visible.
- [ ] Layout spec verifies the active product no longer exposes deleted features.

---

## 7. Concurrency And Race-Condition Tests

- [ ] Two sync operations for the same shop do not create duplicate issue rows.
- [ ] Re-running the audit service on the same data set does not change fingerprints.
- [ ] Concurrent webhook and manual sync paths do not corrupt the catalog state.
- [ ] Uniqueness constraints prevent duplicate products or variants under concurrency.

---

## 8. Security Tests

- [ ] Unauthorized requests fail cleanly.
- [ ] Tenant isolation prevents cross-shop reads.
- [ ] Webhook HMAC verification blocks tampered requests.
- [ ] SQL injection attempts are safe.
- [ ] Rate limits return 429 when thresholds are exceeded.
- [ ] Security headers stay present in the response.

---

## 9. Cleanup Tests

- [ ] Delete specs for onboarding, demo, imports, suppliers, and purchase orders once the code is removed.
- [ ] Delete specs for inventory monitoring and low-stock automation once they are no longer part of the active product.
- [ ] Delete specs for Clerk webhook handling if the code path is retired.
- [ ] Remove any spec factories that only support deleted features.

---

## 10. Progress Tracker

| Area | Status | Notes |
|---|---|---|
| CI and security gates | In progress | Need continuous verification for the lean stack |
| Request specs | Partial | Core flow exists, deeper coverage still needed |
| Service specs | Partial | Catalog audit service needs broader coverage |
| Job specs | Partial | Lean sync path needs idempotency coverage |
| Model specs | Partial | Remove old feature-era assumptions |
| Cleanup tests | Open | Delete stale inventory-era specs as code is removed |

---

## 11. Recommended Order

1. Lock down the active request specs for connect, dashboard, issues, and settings.
2. Finish service coverage for `Catalog::AuditService`.
3. Add concurrency tests for the sync path.
4. Delete obsolete specs as legacy code disappears.
5. Re-measure LOC after each cleanup tranche.

