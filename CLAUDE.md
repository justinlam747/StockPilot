# CLAUDE.md — Company Vision & Development Guidelines

## Who We Are

We build **Inventory Intelligence**, an embedded Shopify app that gives merchants real-time visibility into their stock levels, automates reorder workflows, and surfaces AI-powered insights — so they never lose a sale to an out-of-stock shelf.

## What We're Building

A production-grade Shopify embedded app with:

- **Real-time low-stock alerts** with configurable thresholds per variant
- **Automated purchase order drafts** generated via Claude AI and sent to suppliers
- **Weekly inventory reports** with trend analysis, timezone-aware scheduling
- **Supplier management** — track lead times, contacts, and order history
- **Customer DNA profiles** built from order history for smarter merchandising
- **GDPR-compliant webhook handling** for data requests and redaction

### Tech Stack

| Layer | Technology |
|-------|-----------|
| Backend | Ruby on Rails 7.2 (API mode) |
| Frontend | React 18 + TypeScript 5.6 + Shopify Polaris 13 |
| Database | PostgreSQL 16 |
| Cache / Queue | Redis 7 + Sidekiq 7 |
| AI | Anthropic Claude API |
| Build | Vite 6 + Vite Ruby 3 |
| Containers | Docker + docker-compose |
| Error Tracking | Sentry |

---

## Design System — White & Grey

### Color Palette

| Token | Value | Usage |
|---|---|---|
| `--color-bg` | `#FFFFFF` | Page background, card backgrounds, button backgrounds |
| `--color-bg-hover` | `#F6F6F7` | Hover states, table stripe rows, secondary surfaces |
| `--color-bg-pressed` | `#EDEEEF` | Active/pressed states, disabled surfaces, dividers |
| `--color-stroke` | `#C9CCCF` | Borders, button outlines, separators |
| `--color-stroke-light` | `#E1E3E5` | Subtle borders, input field borders |
| `--color-text` | `#1A1A1A` | Primary body text (never pure `#000000`) |
| `--color-text-secondary` | `#6D7175` | Button labels, placeholders, secondary text |
| `--color-text-disabled` | `#8C9196` | Disabled text |
| `--color-link` | `#2C6ECB` | Links only — the sole non-grey color allowed |
| `--color-destructive` | `#D72C0D` | Destructive action text only — no fill |

### Hard Rules

- **No gradients.** Every background is a flat solid — white or grey.
- **No black buttons.** No filled buttons. No dark buttons. No `tone="primary"` (renders green/black fill).
- **All buttons:** white background (`#FFFFFF`), 1px grey border (`#C9CCCF`), grey text (`#6D7175`). Hover = `#F6F6F7` bg. Pressed = `#EDEEEF` bg.
- **Primary vs secondary buttons:** Differentiate with text weight (semibold for primary) or an icon. Never with color fills.
- **Destructive buttons:** Grey border, `#D72C0D` text, white background. No red fill.
- **Text:** `#1A1A1A` for body copy. Never pure `#000000`.
- **No shadows** heavier than Polaris `--p-shadow-100`.
- **Badges/status indicators:** Use muted Polaris semantic tones (`subdued`, `warning`, `critical`) but keep them understated.

### Polaris Component Mapping

```
✅ Use: <Button variant="tertiary">   → grey text, no fill
✅ Use: <Button plain>                → text-only button
✅ Use: <Card background="bg">        → white card
❌ Never: <Button variant="primary">  → renders filled/dark
❌ Never: <Button tone="critical">    → renders red fill
❌ Never: background gradients, box-shadow beyond --p-shadow-100
```

---

## Guardrails — What We Do NOT Do

### 1. Never Push Secrets

- **NEVER commit API keys, tokens, or credentials** to the repository
- All secrets go in environment variables (see `.env.example` for the template)
- Files that must stay out of version control:
  - `.env` / `.env.local` / `.env.production`
  - `credentials.json`, `service-account.json`
  - Any file containing `SHOPIFY_API_SECRET`, `ANTHROPIC_API_KEY`, `SENTRY_DSN`, or database passwords
- If you accidentally commit a secret, **rotate it immediately** — git history is forever

### 2. Never Push Directly — Open a PR

- **No direct pushes to `main`** — every change goes through a pull request
- PRs require at least one review before merge
- Branch naming convention: `claude/<description>-<id>` or `<author>/<feature-description>`
- Write a clear PR title and description explaining *what* and *why*
- Link the related GitHub Issue in every PR

### 3. Create GitHub Issues for Everything

- Every feature, bug, and task gets a **GitHub Issue** before work begins
- Use labels: `bug`, `feature`, `chore`, `ci`, `docs`, `security`
- Issues should include:
  - Clear description of the problem or feature
  - Acceptance criteria
  - Affected area of the codebase
- Reference issue numbers in commits and PRs (e.g., `Fixes #42`)

### 4. CI Pipeline — Build It Incrementally

We start from scratch and iterate. Document every CI function in the CI doc below.

#### Current CI Functions

Track all CI pipeline stages here. Add new entries as pipeline evolves:

| Stage | Tool | What It Does | Added Date |
|-------|------|-------------|------------|
| Lint (Ruby) | RuboCop (Rails Omakase) | Enforces Ruby style and Rails best practices | 2026-03-09 |
| Lint (JS/TS) | ESLint | Enforces TypeScript/React code standards | 2026-03-09 |
| Type Check | TypeScript (`tsc --noEmit`) | Catches type errors before runtime | 2026-03-09 |
| Unit Tests (Backend) | RSpec 7 | Runs model, service, and job specs | 2026-03-09 |
| Unit Tests (Frontend) | Vitest 2.1 | Runs React component and hook tests | 2026-03-09 |
| Request Tests | RSpec (request specs) | Tests full API endpoint behavior | 2026-03-09 |
| Security Scan | `bundler-audit` | Checks gems for known CVEs | 2026-03-09 |
| Secret Detection | `git-secrets` / CI check | Prevents accidental credential commits | 2026-03-09 |
| Build | Vite (`vite build`) | Ensures frontend compiles cleanly | 2026-03-09 |
| Docker Build | `docker build` | Validates the container image builds | 2026-03-09 |

#### CI Pipeline Iteration Rules

- **Every new CI function gets added to the table above** before merging
- CI must pass before any PR can be merged
- If a CI stage is flaky, fix it — don't skip it
- Never use `--no-verify` to bypass pre-commit hooks
- Pipeline changes are reviewed like any other code change

### 5. Code Quality Standards

- **No `any` types in TypeScript** — use proper types or `unknown`
- **No skipped tests** — `xit`, `xdescribe`, `.skip` require an Issue link explaining why
- **No `TODO` without an Issue** — every TODO comment must reference a GitHub Issue number
- **No dead code** — remove unused imports, functions, and variables
- **No console.log in production code** — use proper logging (Sentry, Rails logger)

### 6. Security Rules

#### 6a. Authentication & Session Security (Shopify-Specific)

- **Session token validation is mandatory** — use Shopify App Bridge session tokens for all frontend-to-backend requests; never trust URL query params after initial load
- **HMAC verification on every webhook** — already handled by `ShopifyApp::WebhookVerification`, never bypass it
- **Token exchange flow** — exchange App Bridge session tokens for access tokens server-side using Shopify's token exchange API; never expose access tokens to the browser
- **Session expiry** — configure explicit session timeouts (recommend 24h max); re-validate the session's shop matches the requesting shop on every API call to prevent cross-merchant token reuse
- **OAuth scopes** — request only the minimum scopes needed (currently: `read_products,read_inventory,read_orders,read_customers`); never request `write_` scopes unless the feature demands it

#### 6b. CORS — Restrict Origins (CRITICAL)

- **NEVER use `origins "*"`** — this exposes the API to cross-origin data theft and CSRF
- Restrict CORS to your app's domain and Shopify admin:
  ```ruby
  origins "https://your-app-domain.com", "https://admin.shopify.com"
  ```
- Current config in `config/initializers/cors.rb` allows all origins — **this must be fixed before production**

#### 6c. Rate Limiting & Abuse Prevention

- **Implement `rack-attack`** for API rate limiting — protect against brute force, DoS, and abuse of expensive endpoints (especially AI/insights generation)
- Recommended limits:
  - General API: 60 requests/minute per shop
  - AI endpoints: 10 requests/minute per shop
  - Webhook delivery: 100 requests/minute
- **Respect Shopify API throttle limits** — already handled in `Shopify::GraphqlClient` with retry logic
- **Alternative:** Rails 7.2+ has built-in rate limiting (`rate_limit to: 10, within: 3.minutes, only: :create`) — useful for simple per-action throttling without extra gems

#### 6d. Input Validation & Strong Parameters

- **Validate all user input at the controller boundary** — use Rails `strong_parameters` (`.require().permit()`) on every controller action
- **Never trust client-side validation alone** — always validate server-side
- Validate data types, lengths, formats, and ranges
- Use parameterized queries — never interpolate user input into SQL
- Sanitize any data before rendering in the frontend (React auto-escapes JSX, but avoid `dangerouslySetInnerHTML`)
- **File uploads:** If added later, whitelist allowed extensions AND validate media types; limit file sizes
- **Never use string interpolation in SQL** — `Project.where("name = '#{name}'")` is injectable; use `where(name: name)` or `sanitize_sql`

#### 6e. Authorization & Access Control

- **Authentication is not authorization** — verifying a shop session doesn't mean the user can access all resources
- Implement resource-level authorization (recommend `pundit` gem) for:
  - Settings modification
  - Supplier management
  - Purchase order creation/approval
  - AI insights generation
- All queries must be scoped to the current tenant — `acts_as_tenant` handles this, **never bypass it**

#### 6f. Security Headers

Every response must include these headers (configure in `config/environments/production.rb`):

| Header | Value | Purpose |
|--------|-------|---------|
| `Strict-Transport-Security` | `max-age=31536000; includeSubDomains` | Force HTTPS |
| `X-Content-Type-Options` | `nosniff` | Prevent MIME sniffing |
| `X-Frame-Options` | `ALLOWALL` (embedded apps) | Shopify embeds in iframe |
| `Content-Security-Policy` | `frame-ancestors https://*.myshopify.com https://admin.shopify.com` | Restrict iframe embedding to Shopify |
| `Referrer-Policy` | `strict-origin-when-cross-origin` | Limit referrer leakage |
| `Permissions-Policy` | `camera=(), microphone=(), geolocation=()` | Disable unused browser APIs |

#### 6g. Data Encryption & Protection

- **At rest:** Shopify access tokens encrypted via `encrypts :access_token` (already in `Shop` model)
- **In transit:** SSL enforced in production via `config.force_ssl = true`
- **In the browser:** Never store tokens in `localStorage` or `sessionStorage` — keep all tokens server-side
- **Redis:** Use TLS connections in production (`rediss://` protocol) with `ssl_params: { verify_mode: OpenSSL::SSL::VERIFY_PEER }`; set `maxmemory-policy noeviction` so Redis never silently drops Sidekiq jobs; use **separate Redis instances** for caching (LRU eviction) vs. Sidekiq (no eviction)
- **Sidekiq job arguments are stored unencrypted in Redis** — never pass tokens, PII, or secrets as job args; pass record IDs and look up sensitive data inside the job
- **Database:** Use `DATABASE_URL` with SSL mode in production (`?sslmode=require`)

#### 6h. API Key & Secret Management

- All secrets via environment variables — never hardcoded
- **Anthropic API key:** When implementing AI services, never log request/response payloads that contain the API key; implement circuit breakers for API failures; validate and sanitize all AI-generated content before returning to the frontend
- **Shopify API credentials:** Managed by the `shopify_app` gem via ENV vars
- **SendGrid API key:** Validate email addresses before sending; rate-limit outbound emails to prevent spam
- **Rails master key:** Required for credential decryption; never commit `config/master.key`

#### 6i. Logging Security — What NOT to Log

- **Never log:** access tokens, API keys, passwords, session tokens, credit card numbers, full email addresses, Shopify HMAC signatures
- **Already configured** in `config/initializers/filter_parameter_logging.rb`: filters `:passw, :secret, :token, :_key, :crypt, :salt, :certificate, :otp, :ssn, :access_token, :api_key`
- **Also filter:** request headers containing `Authorization`, webhook payloads with merchant PII, AI prompt/response content that includes merchant data
- Use structured logging with request IDs for audit trails (already configured: `config.log_tags = [:request_id]`)

#### 6j. GDPR & Privacy Compliance

- **Mandatory Shopify requirements** — all apps must handle these webhooks:
  - `customers/data_request` — export all stored customer data
  - `customers/redact` — delete all stored customer data
  - `shop/redact` — delete all stored shop data after uninstall
- **Current status:** GDPR endpoints in `GdprController` return `200 OK` but don't process data — **these must be fully implemented before app store submission**
- **Data minimization:** Only collect and store data you actively use; delete data you no longer need
- **Data retention policy:** Define how long you keep inventory snapshots, customer profiles, and reports; implement automated cleanup (already have `SnapshotCleanupJob`)

#### 6k. Dependency & Supply Chain Security

- **Ruby:** Run `bundle-audit check --update` in CI to detect vulnerable gems
- **Ruby:** Run `brakeman` static analysis to detect Rails security issues (SQL injection, XSS, mass assignment)
- **Node.js:** Run `npm audit` in CI; fail builds on high/critical severity
- **Lock files:** Always commit `Gemfile.lock` and `package-lock.json`; use `bundle install` and `npm ci` (not `npm install`) in CI
- **Dependency updates:** Enable Dependabot or Renovate for automated security patches
- **New packages:** Review before adding; prefer well-maintained packages with security track records

#### 6l. Container & Infrastructure Security

- **Dockerfile:** Use minimal base images (currently `ruby:3.3-slim` — good)
- **No secrets in images:** Never use `ARG` or `ENV` for secrets in Dockerfile; use runtime environment variables
- **Docker Compose:** Move hardcoded Postgres credentials in `docker-compose.yml` to a `.env` file (even for development)
- **Non-root execution:** Run the app as a non-root user inside the container
- **Image scanning:** Add container image vulnerability scanning (Trivy, Snyk Container) to CI

#### 6m. Audit Logging

- **Log all security-relevant events:** login attempts, permission changes, data exports, GDPR requests, failed authentication, rate limit hits
- **Include:** timestamp, shop ID, action, IP address, user agent, request ID
- **Store audit logs separately** from application logs — they may need longer retention for compliance

### 7. Database Rules

- **Every schema change needs a migration** — never modify `schema.rb` directly
- Migrations must be reversible (include `down` methods or use `change`)
- Add database indexes for columns used in `WHERE`, `JOIN`, or `ORDER BY`
- Multi-tenancy: all queries must be scoped to the current shop via `acts_as_tenant`
- Never bypass tenant scoping — it's there to prevent data leakage between merchants

### 8. Git Hygiene

- Write clear commit messages: imperative mood, explain *why* not just *what*
- Keep commits small and focused — one logical change per commit
- Rebase feature branches on `main` before opening a PR
- Delete branches after merge
- Never force-push to shared branches

---

## Pre-Commit Quality Gate

**Before every commit**, run `/review` on all changed files. The review MUST scan for the following three categories. If any blocking issue is found, **do not commit — fix first.**

### 1. Race Conditions

- [ ] Concurrent Sidekiq jobs operating on the same shop's data — can two `InventorySyncJob`s for the same shop run simultaneously and create duplicate snapshots?
- [ ] `find_or_create_by` / `find_or_initialize_by` without a matching unique index — will insert duplicates under concurrency
- [ ] Time-of-check to time-of-use (TOCTOU) — reading a value, making a decision, then writing based on stale data (e.g., checking stock level then creating alert without a lock)
- [ ] Missing advisory locks or `with_lock` on operations that must be atomic
- [ ] Counter/balance updates without database-level atomicity (`UPDATE ... SET count = count + 1` is safe, `record.count += 1; record.save` is not)

### 2. Duplication Logic

- [ ] Can the same alert fire twice for the same variant in one run?
- [ ] Can overlapping sync jobs create duplicate snapshot rows?
- [ ] Is every background job idempotent — safe to retry without creating duplicate records?
- [ ] N+1 queries — loading a collection then querying inside a loop (use `includes`/`joins`/subqueries)
- [ ] Duplicate API calls — is the same Shopify GraphQL query being made multiple times in one request cycle?

### 3. Vulnerabilities at Scale

- [ ] SQL injection via string interpolation — `where("name = '#{input}'")`  must be `where(name: input)`
- [ ] Mass assignment — every controller action uses `strong_parameters` (`.require().permit()`)
- [ ] Tenant isolation — every query scoped by `acts_as_tenant` or explicit `shop_id`. No unscoped queries.
- [ ] Unbounded queries — all list endpoints paginated, all batch operations chunked (`find_each`, `in_batches`)
- [ ] Webhook HMAC — every inbound Shopify webhook controller includes `ShopifyApp::WebhookVerification`
- [ ] No secrets in code — tokens/keys come from `ENV` only, never hardcoded
- [ ] Rate limit handling — all Shopify API calls go through `Shopify::GraphqlClient` with throttle retry
- [ ] Memory — no unbounded array accumulation (e.g., loading all records into an array instead of streaming)

### How to Run

```bash
# Review all staged changes before committing:
# 1. Run /review on the diff
# 2. Fix any blocking issues flagged above
# 3. Only then commit
```

---

## Development Workflow Summary

```
1. Pick or create a GitHub Issue
2. Create a feature branch from main
3. Write code + tests
4. Run CI locally (lint, type-check, test, build)
5. Run /review on changed files — check for race conditions, duplication, and vulnerabilities
6. Fix any blocking issues found
7. Commit with a descriptive message referencing the Issue
8. Push branch and open a PR
9. Get review, address feedback
10. CI passes → merge
11. Delete the branch
```

---

## Running the Project Locally

```bash
# Start all services (Rails, Sidekiq, PostgreSQL, Redis)
docker-compose up

# Run backend tests
bundle exec rspec

# Run frontend tests
npx vitest run

# Lint
bundle exec rubocop
npx eslint frontend/

# Type check
npx tsc --noEmit
```

---

## Environment Variables

See `.env.example` for the full list. Key variables:

- `SHOPIFY_API_KEY` / `SHOPIFY_API_SECRET` — Shopify app credentials
- `ANTHROPIC_API_KEY` — Claude API access
- `DATABASE_URL` — PostgreSQL connection string
- `REDIS_URL` — Redis connection string
- `SENTRY_DSN` — Error tracking
- `RAILS_MASTER_KEY` — Rails credential encryption

**None of these should ever appear in committed code.**

---

## Security Audit Status

Current state of security measures — update as items are resolved:

| Area | Status | Notes |
|------|--------|-------|
| Shopify OAuth | Done | `shopify_app` gem v22, scopes properly scoped |
| Session token validation | Done | `ShopifyApp::EnsureHasSession` on all authenticated routes |
| Webhook HMAC verification | Done | `ShopifyApp::WebhookVerification` on webhook + GDPR controllers |
| Access token encryption | Done | `encrypts :access_token` in Shop model |
| Multi-tenancy isolation | Done | `acts_as_tenant :shop` on all models |
| SSL in production | Done | `config.force_ssl = true` |
| Parameter log filtering | Done | Filters tokens, keys, passwords, SSNs |
| Sentry error tracking | Done | Production + staging |
| Secrets via ENV vars | Done | No hardcoded credentials in code |
| `.gitignore` for secrets | Done | `.env`, master key, credentials excluded |
| CORS restriction | **CRITICAL** | Currently `origins "*"` — must restrict to app domain + Shopify |
| Rate limiting (`rack-attack`) | **TODO** | No throttling on any endpoint |
| Security headers (CSP, HSTS) | **TODO** | No headers configured |
| Input validation / strong params | **TODO** | Controllers are stubs, must add `.permit()` |
| Authorization (`pundit`) | **TODO** | Only authentication exists, no resource-level authz |
| GDPR data processing | **TODO** | Endpoints return 200 but don't process/delete data |
| Audit logging | **TODO** | No security event logging |
| `brakeman` static analysis | **TODO** | Not in CI pipeline |
| `npm audit` in CI | **TODO** | Not in CI pipeline |
| Container image scanning | **TODO** | Not in CI pipeline |
| Docker Compose credentials | **TODO** | Hardcoded `postgres:postgres` in docker-compose.yml |
| Session timeout config | **TODO** | No explicit expiry set |

---

*This document is a living guide. Update it as practices evolve — via a PR, of course.*
