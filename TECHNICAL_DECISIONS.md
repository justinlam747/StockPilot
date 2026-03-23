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

## TD-012: Clerk for Authentication over Devise/Auth0

**Date:** 2026-03-22
**Decision:** Use Clerk (clerk-sdk-ruby) for user authentication instead of Devise, Auth0, or rolling our own.
**Why:** Clerk provides production-grade auth (email+password, Google OAuth, MFA) with minimal code. The Ruby SDK integrates with Rails middleware for session validation. The free tier covers 10K MAU which is sufficient for launch. Moving from embedded Shopify app to standalone SaaS requires our own auth system — Clerk lets us ship in days instead of weeks.
**Trade-off:** Adds a SaaS dependency (~$25/mo after free tier). If Clerk has downtime, users can't log in. Mitigated by the fact that Clerk has 99.99% uptime SLA and we can migrate to Devise later if needed since our User model is decoupled from Clerk internals (only stores clerk_user_id).

---

## TD-013: Live Agent Stream via Raw SSE (Not ActionCable or Turbo Streams)

**Date:** 2026-03-23
**Decision:** Implemented real-time agent execution streaming using raw Server-Sent Events (SSE) with `ActionController::Live`, Redis pub/sub, and vanilla JS `EventSource`. Agent runs execute asynchronously in a Sidekiq job, publishing steps to a Redis channel that the SSE endpoint forwards to the browser.
**Why:** The existing synchronous `POST /agents/run` blocked the HTTP request for up to 30 seconds during agent execution, risking timeout on most hosting platforms. SSE provides one-way streaming (correct fit — no upstream needed), works in Shopify embedded iframes (unlike WebSocket upgrades which can fail), and requires no additional dependencies. ActionCable was overkill (full duplex unnecessary, adds Redis adapter complexity). Turbo Streams would create a framework split since the app uses HTMX, not Hotwire.
**Trade-off:** Each SSE connection holds one Puma thread. With default 5 threads per worker, concurrent SSE connections are limited. Mitigated by the fact that agent runs are infrequent (~1-3 per merchant session) and short-lived (5-30s). Steps are persisted to the `agent_runs` table so reconnection replays from DB (Redis pub/sub is fire-and-forget). The old synchronous endpoint remains as HTMX fallback.

---

## TD-014: Route Audit — Restrict Resource Routes to Implemented Actions

**Date:** 2026-03-23
**Decision:** Changed `resources :suppliers` to `only: %i[index create update destroy]` (removing phantom `show` route) and `resources :purchase_orders` to `only: %i[index show]` (removing `new`, `create`, `edit`, `update`, `destroy` routes that had no controller actions).
**Why:** Routes without corresponding controller actions return 500 errors. This is a security concern — it exposes route structure and generates unnecessary error noise. Using `only:` instead of `except:` is more explicit and prevents future route drift.
**Trade-off:** None meaningful. The removed routes had no implementation and were dead endpoints.

---

*Add new entries as decisions are made. Format: TD-XXX, date, decision, why, trade-offs.*
