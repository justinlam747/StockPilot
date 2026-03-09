# Security Compliance Document

**Application:** Inventory Intelligence — Shopify Embedded App
**Version:** 1.0
**Last Updated:** 2026-03-09
**Owner:** Engineering Team

---

## Table of Contents

1. [Overview](#1-overview)
2. [Authentication & Session Security](#2-authentication--session-security)
3. [Authorization & Access Control](#3-authorization--access-control)
4. [Data Protection & Encryption](#4-data-protection--encryption)
5. [CORS Policy](#5-cors-policy)
6. [Rate Limiting & Abuse Prevention](#6-rate-limiting--abuse-prevention)
7. [Input Validation & Injection Prevention](#7-input-validation--injection-prevention)
8. [Security Headers](#8-security-headers)
9. [Secret Management](#9-secret-management)
10. [Logging & Audit Trail](#10-logging--audit-trail)
11. [GDPR & Privacy Compliance](#11-gdpr--privacy-compliance)
12. [Dependency & Supply Chain Security](#12-dependency--supply-chain-security)
13. [Container & Infrastructure Security](#13-container--infrastructure-security)
14. [Multi-Tenancy Isolation](#14-multi-tenancy-isolation)
15. [CI/CD Security Gates](#15-cicd-security-gates)
16. [Compliance Matrix](#16-compliance-matrix)

---

## 1. Overview

This document defines the security compliance requirements for the Inventory Intelligence Shopify embedded app. All controls are derived from the project's development guidelines (`CLAUDE.md`) and aligned with OWASP Top 10, Shopify App Store requirements, and GDPR obligations.

Every feature, bugfix, or infrastructure change **must** satisfy the controls listed here before merging to `main`.

---

## 2. Authentication & Session Security

### Requirements

| ID | Control | Priority |
|----|---------|----------|
| AUTH-01 | Use Shopify App Bridge session tokens for all frontend-to-backend requests | Mandatory |
| AUTH-02 | Never trust URL query parameters after the initial OAuth handshake | Mandatory |
| AUTH-03 | Exchange App Bridge session tokens for access tokens server-side only | Mandatory |
| AUTH-04 | Never expose Shopify access tokens to the browser | Mandatory |
| AUTH-05 | Configure explicit session timeouts (max 24 hours) | Mandatory |
| AUTH-06 | Re-validate that the session's shop matches the requesting shop on every API call | Mandatory |
| AUTH-07 | Request only minimum OAuth scopes required by current features | Mandatory |

### Current Scopes

```
read_products, read_inventory, read_orders, read_customers
```

`write_` scopes must not be added unless a feature explicitly requires them. Any scope change requires a PR with justification.

### Implementation References

- Session validation: `ShopifyApp::EnsureHasSession` applied to all authenticated routes
- Token exchange: handled server-side via the `shopify_app` gem (v22)

---

## 3. Authorization & Access Control

### Requirements

| ID | Control | Priority |
|----|---------|----------|
| AUTHZ-01 | Implement resource-level authorization (e.g., `pundit` gem) | Mandatory |
| AUTHZ-02 | Authorize access to: settings, suppliers, purchase orders, AI insights | Mandatory |
| AUTHZ-03 | Authentication alone is not sufficient — verify the user can access the specific resource | Mandatory |
| AUTHZ-04 | All database queries scoped to the current tenant via `acts_as_tenant` | Mandatory |
| AUTHZ-05 | Never bypass tenant scoping under any circumstances | Mandatory |

---

## 4. Data Protection & Encryption

### At Rest

| ID | Control | Priority |
|----|---------|----------|
| ENC-01 | Shopify access tokens encrypted in the database (`encrypts :access_token` on `Shop` model) | Mandatory |
| ENC-02 | Database connections use SSL in production (`?sslmode=require`) | Mandatory |

### In Transit

| ID | Control | Priority |
|----|---------|----------|
| ENC-03 | SSL enforced in production via `config.force_ssl = true` | Mandatory |
| ENC-04 | Redis connections use TLS in production (`rediss://` protocol) with `ssl_params: { verify_mode: OpenSSL::SSL::VERIFY_PEER }` | Mandatory |

### In the Browser

| ID | Control | Priority |
|----|---------|----------|
| ENC-05 | Never store tokens in `localStorage` or `sessionStorage` | Mandatory |
| ENC-06 | All tokens remain server-side | Mandatory |

### Background Jobs

| ID | Control | Priority |
|----|---------|----------|
| ENC-07 | Never pass tokens, PII, or secrets as Sidekiq job arguments | Mandatory |
| ENC-08 | Pass record IDs only; look up sensitive data inside the job | Mandatory |

### Redis Configuration

| ID | Control | Priority |
|----|---------|----------|
| ENC-09 | Set `maxmemory-policy noeviction` so Redis never silently drops Sidekiq jobs | Mandatory |
| ENC-10 | Use separate Redis instances for caching (LRU eviction) vs. Sidekiq (no eviction) | Recommended |

---

## 5. CORS Policy

### Requirements

| ID | Control | Priority |
|----|---------|----------|
| CORS-01 | **Never** use `origins "*"` | Critical |
| CORS-02 | Restrict CORS origins to the app domain and `https://admin.shopify.com` | Critical |

### Expected Configuration

```ruby
# config/initializers/cors.rb
origins "https://your-app-domain.com", "https://admin.shopify.com"
```

**Current Status: NON-COMPLIANT** — `origins "*"` is set and must be fixed before production deployment.

---

## 6. Rate Limiting & Abuse Prevention

### Requirements

| ID | Control | Priority |
|----|---------|----------|
| RATE-01 | Implement API rate limiting via `rack-attack` or Rails built-in `rate_limit` | Mandatory |
| RATE-02 | General API: max 60 requests/minute per shop | Mandatory |
| RATE-03 | AI/insights endpoints: max 10 requests/minute per shop | Mandatory |
| RATE-04 | Webhook delivery: max 100 requests/minute | Mandatory |
| RATE-05 | Respect Shopify API throttle limits with retry logic | Mandatory |

---

## 7. Input Validation & Injection Prevention

### Requirements

| ID | Control | Priority |
|----|---------|----------|
| INPUT-01 | Use Rails strong parameters (`.require().permit()`) on every controller action | Mandatory |
| INPUT-02 | Never trust client-side validation alone — always validate server-side | Mandatory |
| INPUT-03 | Validate data types, lengths, formats, and ranges | Mandatory |
| INPUT-04 | Use parameterized queries only — never interpolate user input into SQL | Mandatory |
| INPUT-05 | Never use `dangerouslySetInnerHTML` without sanitization | Mandatory |
| INPUT-06 | File uploads (if added): whitelist extensions, validate media types, limit file sizes | Mandatory |

### Prohibited Patterns

```ruby
# NEVER do this — SQL injection risk
Project.where("name = '#{name}'")

# Do this instead
Project.where(name: name)
```

---

## 8. Security Headers

All production responses **must** include the following headers:

| ID | Header | Required Value | Purpose |
|----|--------|---------------|---------|
| HDR-01 | `Strict-Transport-Security` | `max-age=31536000; includeSubDomains` | Force HTTPS |
| HDR-02 | `X-Content-Type-Options` | `nosniff` | Prevent MIME sniffing |
| HDR-03 | `X-Frame-Options` | `ALLOWALL` | Allow Shopify iframe embedding |
| HDR-04 | `Content-Security-Policy` | `frame-ancestors https://*.myshopify.com https://admin.shopify.com` | Restrict iframe to Shopify |
| HDR-05 | `Referrer-Policy` | `strict-origin-when-cross-origin` | Limit referrer leakage |
| HDR-06 | `Permissions-Policy` | `camera=(), microphone=(), geolocation=()` | Disable unused browser APIs |

Configure in `config/environments/production.rb`.

---

## 9. Secret Management

### Requirements

| ID | Control | Priority |
|----|---------|----------|
| SEC-01 | All secrets stored as environment variables — never hardcoded | Mandatory |
| SEC-02 | Never commit `.env`, `.env.local`, `.env.production`, `credentials.json`, `service-account.json` | Mandatory |
| SEC-03 | Never commit files containing `SHOPIFY_API_SECRET`, `ANTHROPIC_API_KEY`, `SENTRY_DSN`, or database passwords | Mandatory |
| SEC-04 | Never commit `config/master.key` | Mandatory |
| SEC-05 | If a secret is accidentally committed, rotate it immediately | Mandatory |
| SEC-06 | Never log API keys, tokens, passwords, or HMAC signatures | Mandatory |
| SEC-07 | Never pass secrets as Dockerfile `ARG` or `ENV` — use runtime environment variables | Mandatory |

### Protected Environment Variables

| Variable | Purpose |
|----------|---------|
| `SHOPIFY_API_KEY` / `SHOPIFY_API_SECRET` | Shopify app credentials |
| `ANTHROPIC_API_KEY` | Claude AI API access |
| `DATABASE_URL` | PostgreSQL connection |
| `REDIS_URL` | Redis connection |
| `SENTRY_DSN` | Error tracking |
| `RAILS_MASTER_KEY` | Rails credential encryption |

### Anthropic API Key — Additional Controls

| ID | Control | Priority |
|----|---------|----------|
| SEC-08 | Never log request/response payloads containing the API key | Mandatory |
| SEC-09 | Implement circuit breakers for API failures | Mandatory |
| SEC-10 | Validate and sanitize all AI-generated content before returning to frontend | Mandatory |

---

## 10. Logging & Audit Trail

### What NOT to Log

| ID | Prohibited Data |
|----|----------------|
| LOG-01 | Access tokens, API keys, passwords, session tokens |
| LOG-02 | Credit card numbers, full email addresses |
| LOG-03 | Shopify HMAC signatures |
| LOG-04 | `Authorization` request headers |
| LOG-05 | Webhook payloads containing merchant PII |
| LOG-06 | AI prompt/response content containing merchant data |

### Parameter Filtering

Configured in `config/initializers/filter_parameter_logging.rb`:

```
:passw, :secret, :token, :_key, :crypt, :salt, :certificate, :otp, :ssn, :access_token, :api_key
```

### Audit Logging Requirements

| ID | Control | Priority |
|----|---------|----------|
| AUDIT-01 | Log all security-relevant events: login attempts, permission changes, data exports, GDPR requests, failed auth, rate limit hits | Mandatory |
| AUDIT-02 | Include: timestamp, shop ID, action, IP address, user agent, request ID | Mandatory |
| AUDIT-03 | Store audit logs separately from application logs | Mandatory |
| AUDIT-04 | Use structured logging with request IDs (`config.log_tags = [:request_id]`) | Mandatory |

---

## 11. GDPR & Privacy Compliance

### Mandatory Shopify Webhooks

| ID | Webhook | Handler | Requirement |
|----|---------|---------|-------------|
| GDPR-01 | `customers/data_request` | `GdprController` | Export all stored customer data on request |
| GDPR-02 | `customers/redact` | `GdprController` | Delete all stored customer data |
| GDPR-03 | `shop/redact` | `GdprController` | Delete all stored shop data after uninstall |

**Current Status: NON-COMPLIANT** — Endpoints return `200 OK` but do not process or delete data. Must be fully implemented before Shopify App Store submission.

### Data Minimization

| ID | Control | Priority |
|----|---------|----------|
| GDPR-04 | Only collect and store data that is actively used | Mandatory |
| GDPR-05 | Delete data that is no longer needed | Mandatory |
| GDPR-06 | Define and enforce data retention policies for inventory snapshots, customer profiles, and reports | Mandatory |
| GDPR-07 | Implement automated data cleanup (`SnapshotCleanupJob`) | Mandatory |

### Webhook Security

| ID | Control | Priority |
|----|---------|----------|
| GDPR-08 | HMAC verification on every webhook — never bypass `ShopifyApp::WebhookVerification` | Mandatory |

---

## 12. Dependency & Supply Chain Security

### Requirements

| ID | Control | Priority |
|----|---------|----------|
| DEP-01 | Run `bundle-audit check --update` in CI to detect vulnerable gems | Mandatory |
| DEP-02 | Run `brakeman` static analysis in CI for Rails security issues | Mandatory |
| DEP-03 | Run `npm audit` in CI — fail builds on high/critical severity | Mandatory |
| DEP-04 | Always commit `Gemfile.lock` and `package-lock.json` | Mandatory |
| DEP-05 | Use `bundle install` and `npm ci` (not `npm install`) in CI | Mandatory |
| DEP-06 | Enable Dependabot or Renovate for automated security patches | Recommended |
| DEP-07 | Review new packages before adding — prefer well-maintained packages | Mandatory |

---

## 13. Container & Infrastructure Security

### Requirements

| ID | Control | Priority |
|----|---------|----------|
| CONT-01 | Use minimal base images (`ruby:3.3-slim`) | Mandatory |
| CONT-02 | Never use `ARG` or `ENV` for secrets in Dockerfile | Mandatory |
| CONT-03 | Move hardcoded Postgres credentials in `docker-compose.yml` to `.env` file | Mandatory |
| CONT-04 | Run the app as a non-root user inside the container | Mandatory |
| CONT-05 | Add container image vulnerability scanning (Trivy, Snyk) to CI | Recommended |

---

## 14. Multi-Tenancy Isolation

### Requirements

| ID | Control | Priority |
|----|---------|----------|
| TENANT-01 | All models use `acts_as_tenant :shop` | Mandatory |
| TENANT-02 | All database queries scoped to the current shop | Mandatory |
| TENANT-03 | Never bypass tenant scoping — prevents data leakage between merchants | Mandatory |
| TENANT-04 | Every schema change must preserve tenant isolation | Mandatory |

---

## 15. CI/CD Security Gates

The following security checks **must** pass before any PR can be merged:

| Gate | Tool | Blocks Merge |
|------|------|:------------:|
| Ruby lint | RuboCop | Yes |
| JS/TS lint | ESLint | Yes |
| Type check | `tsc --noEmit` | Yes |
| Backend tests | RSpec | Yes |
| Frontend tests | Vitest | Yes |
| Request tests | RSpec request specs | Yes |
| Gem vulnerability scan | `bundler-audit` | Yes |
| Secret detection | `git-secrets` | Yes |
| Frontend build | Vite | Yes |
| Docker build | `docker build` | Yes |

### Pipeline Rules

- CI must pass before any PR merge
- Flaky CI stages must be fixed, not skipped
- Never use `--no-verify` to bypass pre-commit hooks
- Pipeline changes are reviewed like any other code change
- Every new CI stage is documented in `CLAUDE.md` before merging

---

## 16. Compliance Matrix

Summary of current compliance status across all controls:

| Area | Status | Compliance | Tracking |
|------|--------|:----------:|----------|
| Shopify OAuth | Implemented | Compliant | — |
| Session token validation | Implemented | Compliant | — |
| Webhook HMAC verification | Implemented | Compliant | — |
| Access token encryption | Implemented | Compliant | — |
| Multi-tenancy isolation | Implemented | Compliant | — |
| SSL enforcement | Implemented | Compliant | — |
| Parameter log filtering | Implemented | Compliant | — |
| Sentry error tracking | Implemented | Compliant | — |
| Secrets via ENV vars | Implemented | Compliant | — |
| `.gitignore` for secrets | Implemented | Compliant | — |
| CORS restriction | **Not implemented** | **Non-Compliant** | CRITICAL — `origins "*"` must be fixed |
| Rate limiting | **Not implemented** | **Non-Compliant** | Needs `rack-attack` or Rails `rate_limit` |
| Security headers | **Not implemented** | **Non-Compliant** | CSP, HSTS, etc. not configured |
| Input validation | **Not implemented** | **Non-Compliant** | Controllers need `.permit()` |
| Authorization | **Not implemented** | **Non-Compliant** | No resource-level authz |
| GDPR data processing | **Not implemented** | **Non-Compliant** | Endpoints are stubs |
| Audit logging | **Not implemented** | **Non-Compliant** | No security event logging |
| `brakeman` in CI | **Not implemented** | **Non-Compliant** | Not in pipeline |
| `npm audit` in CI | **Not implemented** | **Non-Compliant** | Not in pipeline |
| Container scanning | **Not implemented** | **Non-Compliant** | Not in pipeline |
| Docker Compose credentials | **Not implemented** | **Non-Compliant** | Hardcoded `postgres:postgres` |
| Session timeout config | **Not implemented** | **Non-Compliant** | No explicit expiry |

---

## Revision History

| Date | Version | Author | Changes |
|------|---------|--------|---------|
| 2026-03-09 | 1.0 | Engineering | Initial compliance document derived from CLAUDE.md |

---

*This is a living document. All changes must go through a pull request and code review.*
