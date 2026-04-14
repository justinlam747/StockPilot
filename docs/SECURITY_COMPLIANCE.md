# Security Compliance Document

**Application:** Catalog Audit - Shopify Embedded App
**Version:** 3.0
**Last Updated:** 2026-04-14
**Owner:** Engineering Team

---

## 1. Overview

This document defines the security requirements for Catalog Audit. The product is intentionally lean: connect a Shopify store, sync catalog data, compute issues, and review them in the app.

All changes that affect auth, data handling, rate limits, tenant isolation, or Shopify integration must satisfy this document before merge.

---

## 2. Authentication And Session Security

### Requirements

| ID | Control | Priority |
|---|---|---|
| AUTH-01 | Use Shopify App Bridge session tokens for authenticated frontend-to-backend requests | Mandatory |
| AUTH-02 | Never trust query params after the OAuth handshake | Mandatory |
| AUTH-03 | Exchange tokens server-side only | Mandatory |
| AUTH-04 | Never expose Shopify access tokens to the browser | Mandatory |
| AUTH-05 | Keep session lifetimes explicit and short | Mandatory |
| AUTH-06 | Re-check that the active shop matches the requesting shop on every API call | Mandatory |
| AUTH-07 | Request only the minimum OAuth scopes needed for the active product | Mandatory |

### Current Scope Policy

Use the smallest scope set that supports catalog sync and issue review. Add new scopes only when a rule or integration genuinely requires them.

---

## 3. Authorization And Tenant Isolation

Catalog Audit is merchant-scoped. The current product does not rely on broad internal admin roles.

### Requirements

| ID | Control | Priority |
|---|---|---|
| AUTHZ-01 | Scope every query to the connected shop | Mandatory |
| AUTHZ-02 | Never bypass tenant scoping | Mandatory |
| AUTHZ-03 | If role-based admin features return, add resource authorization at that time | Deferred |

---

## 4. Data Protection And Encryption

### At Rest

| ID | Control | Priority |
|---|---|---|
| ENC-01 | Encrypt Shopify access tokens in the database | Mandatory |
| ENC-02 | Use SSL for the database connection in production | Mandatory |

### In Transit

| ID | Control | Priority |
|---|---|---|
| ENC-03 | Enforce SSL in production | Mandatory |
| ENC-04 | Use TLS for Redis and other remote services in production | Mandatory |

### Browser And Jobs

| ID | Control | Priority |
|---|---|---|
| ENC-05 | Never store tokens in localStorage or sessionStorage | Mandatory |
| ENC-06 | Never pass secrets as Sidekiq job arguments | Mandatory |
| ENC-07 | Pass record IDs to jobs and resolve sensitive data server-side | Mandatory |

---

## 5. CORS Policy

| ID | Control | Priority |
|---|---|---|
| CORS-01 | Never use wildcard origins | Critical |
| CORS-02 | Restrict origins to the app domain and `https://admin.shopify.com` | Critical |

---

## 6. Rate Limiting And Abuse Prevention

### Requirements

| ID | Control | Priority |
|---|---|---|
| RATE-01 | Use `rack-attack` or Rails rate limiting | Mandatory |
| RATE-02 | General merchant requests: 60/minute per shop | Mandatory |
| RATE-03 | Manual sync requests: tighter throttling than general requests | Mandatory |
| RATE-04 | Webhook delivery: 100/minute per IP | Mandatory |
| RATE-05 | Shopify API calls must use retry-aware client code | Mandatory |

---

## 7. Input Validation And Injection Prevention

| ID | Control | Priority |
|---|---|---|
| INPUT-01 | Use strong parameters on every controller write action | Mandatory |
| INPUT-02 | Validate data types, lengths, and formats server-side | Mandatory |
| INPUT-03 | Never interpolate user input into SQL | Mandatory |
| INPUT-04 | Sanitize rendered content when needed | Mandatory |
| INPUT-05 | Treat external payloads as untrusted until validated | Mandatory |

---

## 8. Security Headers

Production responses must include:

| ID | Header | Required Value |
|---|---|---|
| HDR-01 | `Strict-Transport-Security` | `max-age=31536000; includeSubDomains` |
| HDR-02 | `X-Content-Type-Options` | `nosniff` |
| HDR-03 | `X-Frame-Options` | `ALLOWALL` |
| HDR-04 | `Content-Security-Policy` | `frame-ancestors https://*.myshopify.com https://admin.shopify.com` |
| HDR-05 | `Referrer-Policy` | `strict-origin-when-cross-origin` |
| HDR-06 | `Permissions-Policy` | `camera=(), microphone=(), geolocation=()` |

---

## 9. Secret Management

### Requirements

| ID | Control | Priority |
|---|---|---|
| SEC-01 | Store secrets in environment variables only | Mandatory |
| SEC-02 | Never commit `.env`, credentials, master keys, or API secrets | Mandatory |
| SEC-03 | Never log access tokens, API keys, passwords, or HMAC signatures | Mandatory |
| SEC-04 | Filter sensitive params from request logs | Mandatory |
| SEC-05 | Keep Shopify and third-party credentials out of job args | Mandatory |

---

## 10. Logging And Audit Trail

### Requirements

| ID | Control | Priority |
|---|---|---|
| LOG-01 | Log security-relevant events with request IDs | Mandatory |
| LOG-02 | Include shop ID, timestamp, action, and IP where practical | Mandatory |
| LOG-03 | Store durable audit data separately from application logs if needed | Recommended |

The app should log connection events, sync events, webhook failures, GDPR requests, and rate-limit hits without leaking secrets.

---

## 11. GDPR And Privacy

### Mandatory Webhooks

| ID | Webhook | Requirement |
|---|---|---|
| GDPR-01 | `customers/data_request` | Return or document the stored customer data response |
| GDPR-02 | `customers/redact` | Delete customer data if any is stored |
| GDPR-03 | `shop/redact` | Delete shop-scoped data after uninstall |

### Data Minimization

| ID | Control | Priority |
|---|---|---|
| GDPR-04 | Only store data actively used by the product | Mandatory |
| GDPR-05 | Delete data that is no longer required | Mandatory |
| GDPR-06 | Define retention for any persisted audit history if it is added later | Mandatory |
| GDPR-07 | Verify webhook HMAC on every inbound webhook | Mandatory |

---

## 12. Dependency And Supply Chain Security

| ID | Control | Priority |
|---|---|---|
| DEP-01 | Run `bundle-audit` in CI | Mandatory |
| DEP-02 | Run `brakeman` in CI | Mandatory |
| DEP-03 | Review new dependencies before adding them | Mandatory |
| DEP-04 | Commit lockfiles | Mandatory |

---

## 13. Multi-Tenancy Isolation

| ID | Control | Priority |
|---|---|---|
| TENANT-01 | All models and queries must remain shop-scoped | Mandatory |
| TENANT-02 | No cross-shop list or detail leaks | Mandatory |
| TENANT-03 | Every schema change must preserve tenant isolation | Mandatory |

---

## 14. CI/CD Security Gates

The following checks should pass before merge:

| Gate | Tool | Blocks Merge |
|---|---|:---:|
| Ruby lint | RuboCop | Yes |
| Backend tests | RSpec | Yes |
| Gem vulnerability scan | `bundler-audit` | Yes |
| Static security scan | `brakeman` | Yes |

---

## 15. Compliance Matrix

| Area | Status | Notes |
|---|---|---|
| Shopify OAuth | Implemented | Store connection via Shopify OAuth |
| Session token validation | Implemented | Authenticated merchant requests are session-scoped |
| Webhook HMAC verification | Implemented | Required for inbound Shopify webhooks |
| Access token encryption | Implemented | Encrypted at rest |
| Tenant isolation | Implemented | Shop-scoped data access |
| SSL enforcement | Implemented | Enforced in production |
| Parameter filtering | Implemented | Sensitive request params filtered |
| Secrets via ENV vars | Implemented | No hardcoded credentials |
| CORS restriction | Implemented | Restricted to app domain and Shopify admin |
| Rate limiting | Implemented | `rack-attack` active |
| Security headers | Implemented | CSP, HSTS, and frame rules configured |
| Input validation | Implemented | Strong params and model validation |
| Authorization | Deferred | Not needed for the current single-workflow merchant app |
| GDPR handling | Implemented | Webhooks and deletion paths are defined |
| Dependency scanning | Implemented | `bundler-audit` and `brakeman` are required |

---

## 16. Revision History

| Date | Version | Changes |
|---|---|---|
| 2026-04-14 | 3.0 | Reframed from inventory app to Catalog Audit and removed stale supplier / purchase-order language |
| 2026-03-18 | 2.0 | Updated controls for CORS, rate limiting, security headers, input validation, GDPR, audit logging, and Brakeman |
| 2026-03-09 | 1.0 | Initial compliance document |

---

*This is a living document. Update it through a PR when security posture changes.*

