---
name: review
description: Run the pre-commit quality gate from CLAUDE.md — checks for race conditions, duplication logic, and vulnerabilities at scale. Use before every commit.
user-invocable: true
---

## Pre-Commit Quality Gate Review

You are reviewing all staged/changed files against the three mandatory review categories from CLAUDE.md.

### Steps

1. Run `git diff --cached --name-only` and `git diff --name-only` to identify all changed files.
2. Read every changed file.
3. Scan for the following three categories. Report each finding with file path, line number, and severity (BLOCKING or WARNING).

### 1. Race Conditions

- [ ] Concurrent Sidekiq jobs operating on the same shop's data — can two jobs for the same shop run simultaneously and create duplicates?
- [ ] `find_or_create_by` / `find_or_initialize_by` without a matching unique index
- [ ] Time-of-check to time-of-use (TOCTOU) — reading a value, deciding, then writing based on stale data without a lock
- [ ] Missing advisory locks or `with_lock` on operations that must be atomic
- [ ] Counter/balance updates without database-level atomicity (`record.count += 1; record.save` is NOT safe)

### 2. Duplication Logic

- [ ] Can the same alert can u fire twice for the same variant in one run?
- [ ] Can overlapping sync jobs create duplicate snapshot rows?
- [ ] Is every background job idempotent — safe to retry without creating duplicate records?
- [ ] N+1 queries — loading a collection then querying inside a loop (use `includes`/`joins`)
- [ ] Duplicate API calls — same Shopify GraphQL query made multiple times in one request cycle

### 3. Vulnerabilities at Scale

- [ ] SQL injection via string interpolation — `where("name = '#{input}'")`
- [ ] Mass assignment — every controller action uses `.require().permit()`
- [ ] Tenant isolation — every query scoped by `acts_as_tenant` or explicit `shop_id`
- [ ] Unbounded queries — all list endpoints paginated, batch operations chunked
- [ ] Webhook HMAC — inbound Shopify webhook controllers include `ShopifyApp::WebhookVerification`
- [ ] No secrets in code — tokens/keys from `ENV` only
- [ ] Rate limit handling — Shopify API calls go through throttle retry
- [ ] Memory — no unbounded array accumulation

### Output Format

```
## Review Results

### Race Conditions
- [BLOCKING] path/to/file.rb:42 — find_or_create_by without unique index
- [WARNING] ...

### Duplication Logic
- (none found)

### Vulnerabilities at Scale
- [BLOCKING] ...

## Verdict: PASS / FAIL (N blocking issues)
```

If any BLOCKING issues are found, output `FAIL` and list fixes needed. Do NOT tell the user to commit until all blocking issues are resolved.
