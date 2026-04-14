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
**Status:** **Reversed in TD-013.** `WeeklyReportJob` and `ReportMailer` were removed along with the rest of the Clerk/demo feature surface because the feature depended on the User model (which was also removed) and was never actually wired to a working send-email path.

---

## TD-012: Clerk for Authentication over Devise/Auth0

**Date:** 2026-03-22
**Decision:** Use Clerk (clerk-sdk-ruby) for user authentication instead of Devise, Auth0, or rolling our own.
**Why:** Clerk provides production-grade auth (email+password, Google OAuth, MFA) with minimal code. The Ruby SDK integrates with Rails middleware for session validation. The free tier covers 10K MAU which is sufficient for launch. Moving from embedded Shopify app to standalone SaaS requires our own auth system — Clerk lets us ship in days instead of weeks.
**Trade-off:** Adds a SaaS dependency (~$25/mo after free tier). If Clerk has downtime, users can't log in. Mitigated by the fact that Clerk has 99.99% uptime SLA and we can migrate to Devise later if needed since our User model is decoupled from Clerk internals (only stores clerk_user_id).
**Status:** **Reversed in TD-013.** The Clerk integration was never finished — `ApplicationController` never implemented the `clerk_session_user_id` / `current_user` methods the rest of the code and test harness depended on, `VisionController` and `AccountController` skipped a `require_clerk_session` callback that didn't exist, and the Clerk Railtie load order in `application.rb` was broken. The app had been unable to run its test suite end-to-end for weeks as a result.

---

## TD-013: Remove Clerk in Favor of Shopify OAuth as Sole Auth Surface

**Date:** 2026-04-10
**Decision:** Rip out the `clerk-sdk-ruby` gem, `Svix`, the `User` model, the `users` table, `shops.user_id`, and every controller/view/spec/helper that referenced Clerk. Authentication is now exclusively Shopify OAuth (via `omniauth-shopify-oauth2`), keyed on `session[:shopify_domain]`. Each Shop is its own tenant root.
**Why:** The Clerk migration from TD-012 was abandoned mid-flight — `ApplicationController` was missing the `clerk_session_user_id` / `current_user` / `require_clerk_session` methods the rest of the code and test suite expected. Tests had been skipping (blocked by a red lint job) for long enough that nobody noticed the Clerk path had been non-functional for weeks. Two paths forward existed: finish the Clerk integration, or delete it. `CLAUDE.md` itself describes the product as an "embedded Shopify app" with no mention of Clerk, and the feature that motivated Clerk (one user managing multiple Shopify stores) wasn't on any current roadmap. Deletion was cheaper than completion and aligned with the stated product direction.
**Why it matters for the test suite:** Before removal, `spec/requests/*` were raising `NameError: Before process_action callback :require_clerk_session has not been defined` on every authenticated request, and `Rails::Engine#set_autoload_paths` raised `FrozenError` during boot (likely caused by the broken Clerk Railtie load order in `config/application.rb`). Both issues disappeared the moment Clerk was gone. CI went from 0 passing tests to **280 passing tests, 0 failures**.
**Trade-off:** Gives up the ability for one person to manage multiple Shopify stores from a single account. If that ever becomes a requirement, it'll need to be rebuilt, but likely against a simpler session-based model rather than reintroducing Clerk. Also removes the `User` onboarding wizard, which was already orphaned.

---

## TD-014: Pin Rails at 7.2.3 and Document-Ignore CVE-2026-33658

**Date:** 2026-04-10
**Decision:** Pin `gem 'rails', '7.2.3'` in the Gemfile (exact version, not `~>`) and add `--ignore GHSA-p9fm-f462-ggrg` to the `bundle-audit` step in CI with an inline comment explaining why.
**Why:** GHSA-p9fm-f462-ggrg is an Active Storage DoS in proxy mode. This app does not use Active Storage at all — there are no `has_one_attached` / `has_many_attached` declarations anywhere in `app/models`, and `config/environments/development.rb` is the only file that even mentions `ActiveStorage` (guarded by `if defined?(ActiveStorage)`). The advisory is not exploitable here. Rails 7.2.3 is the last release before the 7.2.3.1 set of changes that caused boot-time issues during our testing, so staying on 7.2.3 avoids those without giving up any security posture that's actually relevant to this codebase.
**Trade-off:** Requires that any future reviewer understand why the ignore exists — if the app ever adopts Active Storage, the ignore must be removed and Rails upgraded. The inline comment in `ci.yml` makes this explicit so it doesn't get forgotten.

---

## TD-015: Adopt 11-Plugin RuboCop Suite (Minus `rubocop-sequel`)

**Date:** 2026-04-10
**Decision:** Extend the base `rubocop-rails-omakase` config with `rubocop-performance`, `rubocop-rails`, `rubocop-rspec`, `rubocop-minitest`, `rubocop-rake`, `rubocop-thread_safety`, `rubocop-capybara`, `rubocop-factory_bot`, `rubocop-rspec_rails`, and `rubocop-i18n`. Deliberately exclude `rubocop-sequel`.
**Why:** The base rubocop config was catching style issues but missing important Rails / RSpec / performance patterns — N+1 query smells, Rails-idiom preferences (`where(created_at: range)` over SQL strings), FactoryBot conventions, thread-safety footguns, etc. The 11 plugins together flagged **400+ existing offenses** on first run, most of which auto-corrected cleanly. `rubocop-sequel` was excluded because this codebase is 100% ActiveRecord and the cop false-flags ActiveRecord `#save` calls as "should be `#save_changes`" (a Sequel-only method), which actively introduced a bug in `SuppliersController` when someone had followed its suggestion.
**Trade-off:** More cops means more churn when upgrading Ruby/Rails/the plugins themselves. Mitigated by pinning cop thresholds in `.rubocop.yml` for anything that would otherwise be aesthetic (Metrics/MethodLength, RSpec/ExampleLength, etc.) rather than leaving them at plugin defaults. A few plugin-specific cops are disabled outright when they don't match this project (`Rails/I18nLocaleTexts`, `I18n/GetText/*`, `RSpec/VerifiedDoubles`, etc.) — documented inline in `.rubocop.yml`.

---

*Add new entries as decisions are made. Format: TD-XXX, date, decision, why, trade-offs.*
