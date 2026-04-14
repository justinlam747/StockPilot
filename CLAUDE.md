# CLAUDE.md - Catalog Audit Development Guide

## Who We Are

We build **Catalog Audit**, a lean Shopify embedded app that helps merchants inspect product catalog quality quickly. The product is intentionally narrow: connect a store, sync catalog data, compute issues, and review what needs fixing.

## What We're Building

A production-ready Shopify app with one clear workflow:

- Shopify OAuth connection
- catalog sync for products and variants
- computed catalog issues
- dashboard summary
- filterable issues list
- minimal settings and operational basics

The product must stay small, understandable, and explainable. Avoid rebuilding inventory operations, supplier workflows, purchase orders, reporting suites, or other side quests.

## Product Boundaries

### In Scope

- catalog quality audits
- issue prioritization
- Shopify Admin deep links for fixes
- read-heavy workflows
- a single sync path

### Out of Scope

- supplier management
- purchase orders
- low-stock automation as a product area
- weekly reports
- customer profiling
- multi-store workspace management
- auto-fixing catalog data in v1
- broad store consulting unrelated to catalog quality

## Tech Stack

| Layer | Technology |
|---|---|
| Backend | Ruby on Rails 7.2 |
| Frontend | Server-rendered ERB + Polaris |
| Database | PostgreSQL |
| Queue | Sidekiq |
| PR Workflow | Graphite PR stacks |
| Error Tracking | Sentry |

## Design System - White & Grey

### Color Palette

| Token | Value | Usage |
|---|---|---|
| `--color-bg` | `#FFFFFF` | Page and card backgrounds |
| `--color-bg-hover` | `#F6F6F7` | Hover states |
| `--color-bg-pressed` | `#EDEEEF` | Pressed states |
| `--color-stroke` | `#C9CCCF` | Borders and separators |
| `--color-stroke-light` | `#E1E3E5` | Subtle borders |
| `--color-text` | `#1A1A1A` | Primary text |
| `--color-text-secondary` | `#6D7175` | Secondary text |
| `--color-text-disabled` | `#8C9196` | Disabled text |
| `--color-link` | `#2C6ECB` | Links only |
| `--color-destructive` | `#D72C0D` | Destructive text only |

### Hard Rules

- No gradients.
- No black buttons.
- No filled primary buttons.
- No heavy shadows.
- Use muted Polaris semantic tones for status, but keep them understated.
- Text should stay readable and neutral, never flashy.

### Design Principles

1. Data first, chrome second.
2. Quiet confidence.
3. Native feel inside Shopify Admin.
4. Accessible by default.
5. Progressive density.

## Guardrails

- Never commit secrets.
- Never add product scope without updating the PRD and checklist.
- Remove dead code instead of hiding it.
- No `TODO` without an issue reference.
- No skipped tests without an issue reference.
- Keep functions under 50 lines when practical.
- Keep PR slices small and reviewable.
- Prefer one task per service.
- Keep the codebase trending toward sub-20k LOC.

## PR Workflow

- Every meaningful change should start from a GitHub Issue.
- Use Graphite PR stacks for reviewable slices.
- Keep each PR focused on one logical unit.
- Prefer 200-300 lines of new logic per PR.
- Hard max is 500 lines of new logic unless the slice truly cannot be split.
- Slice work by schema, model, service, controller, UI, and tests when possible.

## Security Rules

### Authentication And Sessions

- Shopify session validation is mandatory for app requests.
- Never trust URL query params after the initial OAuth handshake.
- Exchange session tokens server-side only.
- Never expose Shopify access tokens to the browser.
- Keep session lifetimes explicit and short.
- Request only the minimum OAuth scopes needed for the current product.

### Rate Limiting And Abuse Prevention

- Use `rack-attack` or Rails rate limiting for expensive endpoints.
- Keep sync and webhook paths throttled.
- Do not add new high-cost endpoints without a limit.

### Input Validation

- Use strong parameters on every write endpoint.
- Validate on the server, not just the client.
- Use parameterized queries only.
- Sanitize user-generated content before render.

### Authorization

- Authentication is not authorization.
- If the product regains internal admin roles, add resource-level authorization then.
- All tenant data must remain scoped to the connected shop.

### Security Headers

- Enforce HSTS in production.
- Use `X-Content-Type-Options: nosniff`.
- Allow iframe embedding only from Shopify admin.
- Keep the CSP strict and explicit.

### Data Protection

- Encrypt Shopify tokens at rest.
- Use TLS in transit.
- Do not store secrets in localStorage or sessionStorage.
- Never pass secrets as Sidekiq job arguments.

### Secrets And Logging

- Keep secrets in environment variables.
- Filter tokens, passwords, session IDs, and HMAC values from logs.
- Use structured logging with request IDs.

### GDPR And Privacy

- Handle Shopify GDPR webhooks correctly.
- Store only the data the product actually uses.
- Delete shop data when required by uninstall or redact events.

### Dependency Security

- Run `bundle-audit`.
- Run `brakeman`.
- Review new dependencies before adding them.

## Database Rules

- Every schema change needs a migration.
- Keep migrations reversible.
- Add indexes for `WHERE`, `JOIN`, and `ORDER BY` columns.
- Preserve tenant isolation in every schema change.

## Git Hygiene

- Write clear, imperative commit messages.
- Keep commits small and focused.
- Rebase on the current branch before opening PRs.
- Never force-push shared branches.

## Quality Gate

Before a commit or merge, review the changed files for:

1. Race conditions.
2. Duplicate creation logic.
3. Tenant isolation issues.
4. Unbounded queries.
5. Missing strong parameters.
6. Secret leakage.
7. Missing tests for the active workflow.

If a blocking issue exists, fix it before merging.

## Running Locally

```bash
bundle install
bundle exec rails db:prepare
bundle exec rails server
bundle exec sidekiq -C config/sidekiq.yml
bundle exec rspec
bundle exec rubocop
```

## Environment Variables

- `SHOPIFY_API_KEY`
- `SHOPIFY_API_SECRET`
- `SHOPIFY_APP_URL`
- `DATABASE_URL`
- `REDIS_URL`
- `SENTRY_DSN`
- `RAILS_MASTER_KEY`

## Security Audit Status

Track the current status of the lean product here and update it as the code changes.

## Session Continuity Requirements

Every substantial implementation session must leave enough written context for a fresh session to resume without relying on chat history.

Required continuity files:

- `docs/orchestration/ACTIVE_CONTEXT.md`
- `docs/orchestration/AGENT_WORKBOARD.md`
- `docs/orchestration/CRITIC_LOG.md`

Rules:

- update these files at the end of every major implementation round
- record current product state, blockers, changed files, and next step
- prefer these files over memory when resuming work

## LLM Comment Block Requirement

For non-obvious code, add short high-signal comment blocks that help a future LLM session rebuild intent quickly.

Use comment blocks to explain:

- why the code exists
- what contract or assumption it depends on
- what a future edit must not break

Do not add narration comments for obvious code. Use them sparingly and only where they improve context recovery.

## Technical Decisions Log

Every architectural, security, or engineering decision that matters to the product story must be recorded in `TECHNICAL_DECISIONS.md` with:

- the decision
- why it was made
- the trade-off

