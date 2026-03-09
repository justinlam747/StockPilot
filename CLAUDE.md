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

- Validate all user input at the controller boundary
- Use parameterized queries — never interpolate user input into SQL
- Shopify access tokens must be encrypted at rest (already configured via `encrypts :access_token`)
- GDPR webhooks must be handled — they are mandatory for Shopify apps
- Rate-limit awareness: respect Shopify API throttle limits (handled in `Shopify::GraphqlClient`)
- Sanitize any data before rendering in the frontend

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

## Development Workflow Summary

```
1. Pick or create a GitHub Issue
2. Create a feature branch from main
3. Write code + tests
4. Run CI locally (lint, type-check, test, build)
5. Commit with a descriptive message referencing the Issue
6. Push branch and open a PR
7. Get review, address feedback
8. CI passes → merge
9. Delete the branch
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

*This document is a living guide. Update it as practices evolve — via a PR, of course.*
