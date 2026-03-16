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

*Add new entries as decisions are made. Format: TD-XXX, date, decision, why, trade-offs.*
