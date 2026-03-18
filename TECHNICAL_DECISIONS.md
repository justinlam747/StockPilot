# Technical Decisions Log

A running record of architectural and engineering decisions made in StockPilot, with rationale. Use this for portfolio discussions, interviews, and onboarding context.

---

## TD-001: Multi-Tenancy via `acts_as_tenant`

**Date:** 2026-03-09
**Decision:** Use the `acts_as_tenant` gem scoped to `Shop` for all models.
**Why:** Every Shopify app serves multiple merchants. Without tenant isolation, one merchant could accidentally (or maliciously) access another's data. `acts_as_tenant` enforces `WHERE shop_id = ?` on every query automatically, making it impossible to forget scoping.
**Trade-off:** Slightly harder to write admin/cross-tenant queries. Worth it for the safety guarantee.

---

## TD-002: Webhook HMAC Verification

**Date:** 2026-03-09
**Decision:** Verify every inbound Shopify webhook using HMAC-SHA256 signature comparison.
**Why:** Webhooks are public HTTP endpoints — anyone who knows the URL can send fake payloads. HMAC verification ensures the payload actually came from Shopify by comparing a hash of the request body against the shared secret.
**Implementation:** Custom verification in `WebhooksController` using `OpenSSL::HMAC.hexdigest` against `SHOPIFY_API_SECRET`.

---

## TD-003: Rate Limiting via Rack::Attack

**Date:** 2026-03-15
**Decision:** Implement per-shop and per-IP rate limiting using `rack-attack`.
**Why:** Protects against abuse, brute force, and accidental DDoS from misbehaving clients. AI/insights endpoints are expensive (Claude API calls), so they get tighter limits (5 req/min) vs general API (60 req/min).
**Limits:**
- General API: 60 req/min per shop
- AI endpoints: 5 req/min per shop
- Auth endpoints: 10 req/5 min per IP
- Webhooks: 100 req/min per IP

---

## TD-004: Embedded App Architecture

**Date:** 2026-03-15
**Decision:** Build as an embedded Shopify app (runs inside Shopify Admin iframe).
**Why:** Embedded apps feel native to merchants — no context switching. This requires careful security headers (`X-Frame-Options: ALLOWALL`, CSP `frame-ancestors` restricted to Shopify domains) and session token auth instead of cookies.
**Trade-off:** More complex than standalone, but demonstrates platform integration skills and is required for Shopify App Store.

---

## TD-005: Access Token Encryption at Rest

**Date:** 2026-03-09
**Decision:** Encrypt Shopify access tokens in the database using Rails 7.2 `encrypts :access_token`.
**Why:** If the database is compromised, raw access tokens would let an attacker control every merchant's Shopify store. Encryption at rest ensures tokens are useless without the Rails master key.

---

## TD-006: Custom OAuth via OmniAuth (Not `shopify_app` Gem)

**Date:** 2026-03-09
**Decision:** Implement OAuth using `omniauth-shopify-oauth2` directly instead of the `shopify_app` gem.
**Why:** The `shopify_app` gem bundles a lot of opinionated middleware and views. Using OmniAuth directly gives full control over the auth flow, session management, and error handling — better for learning and for a portfolio piece that demonstrates understanding of OAuth mechanics.
**Trade-off:** More boilerplate to maintain, but every line is intentional and explainable.

---

## TD-007: Separate Redis Instances for Cache vs Sidekiq

**Date:** 2026-03-15
**Decision:** Plan to use separate Redis instances — one for caching (LRU eviction) and one for Sidekiq (no eviction).
**Why:** If a single Redis instance runs out of memory with LRU eviction, it could silently drop Sidekiq jobs. With `noeviction` policy, Redis returns errors instead of dropping data — but that would break caching. Separate instances let each use the right eviction policy.

---

## TD-008: Comprehensive Model Validations

**Date:** 2026-03-18
**Decision:** Add presence, format, numericality, and inclusion validations to all ActiveRecord models.
**Why:** Models had zero validations — any data could be written to the database regardless of format or completeness. This is a data integrity risk; invalid data silently corrupts business logic (e.g., alerts with missing types, suppliers with negative lead times, snapshots with nil quantities).
**Trade-off:** Slightly stricter — existing seed data or test factories may need updates. Worth it because validations catch bugs at the source rather than in downstream services.

---

## TD-009: Fix Missing Database Columns (alerts.threshold, alerts.dismissed, etc.)

**Date:** 2026-03-18
**Decision:** Add migration for `alerts.threshold`, `alerts.current_quantity`, `alerts.dismissed`, `purchase_orders.order_date`, `purchase_orders.expected_delivery`, and performance indexes.
**Why:** Application code (AlertSender, AlertsController, factories) referenced these columns but they didn't exist in the schema. This would cause `ActiveRecord::UnknownAttributeError` at runtime — a production-blocking bug.
**Trade-off:** None — this was a straightforward schema gap that needed filling.

---

## TD-010: Fix Double request.body.read Bug in Webhook/GDPR Controllers

**Date:** 2026-03-18
**Decision:** Memoize the webhook body via `@webhook_body ||= request.body.read` and rewind the body stream in GDPR controller after HMAC verification.
**Why:** The `request.body` is a stream — reading it once exhausts it. The HMAC verification `before_action` read the body for signature checking, then `receive` tried to read it again for JSON parsing and got an empty string. This meant ALL webhook product updates were silently failing with empty payloads.
**Trade-off:** None — pure bug fix.

---

## TD-011: Weekly Report Job with Timezone-Aware Scheduling

**Date:** 2026-03-18
**Decision:** Create `WeeklyReportJob` that respects each shop's configured timezone when determining the report week boundaries. Scheduled via sidekiq-cron every Monday at 9 AM UTC.
**Why:** The `WeeklyReportAllShopsJob` was referenced in the cron schedule but never existed. The `Reports::WeeklyGenerator` and `ReportMailer` were built but never connected. This closes the loop so merchants actually receive their weekly reports.
**Trade-off:** Running at 9 AM UTC means different local times for different merchants. A per-shop cron would be more precise but adds complexity — UTC scheduling with timezone-aware week boundaries is a reasonable compromise.

---

*Add new entries as decisions are made. Format: TD-XXX, date, decision, why, trade-offs.*
