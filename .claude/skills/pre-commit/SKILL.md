---
name: pre-commit
description: Run the full local CI suite — lint, type-check, test, and build. Use before committing to catch issues early.
user-invocable: true
---

## Local CI Check

Run all CI checks locally before committing.

### Steps

Run these checks in order. Stop and report on the first failure.

1. **Ruby Lint** — `bundle exec rubocop --format simple`
2. **JS/TS Lint** — `npx eslint frontend/`
3. **Type Check** — `npx tsc --noEmit`
4. **Backend Tests** — `bundle exec rspec --format progress`
5. **Frontend Tests** — `npx vitest run`
6. **Build** — `npx vite build`

### Output Format

```
## Local CI Results

| Check | Status | Details |
|-------|--------|---------|
| RuboCop | PASS | 0 offenses |
| ESLint | PASS | 0 warnings |
| TypeScript | FAIL | 3 errors in src/pages/... |
| RSpec | SKIP | (stopped at TypeScript failure) |
| Vitest | SKIP | |
| Vite Build | SKIP | |

## Verdict: PASS / FAIL

### Failures
- tsc: Type 'string' is not assignable to type 'number' in InventoryPage.tsx:42
```

If any check fails, show the errors and suggest fixes. Do NOT proceed to later checks if an earlier one fails — fix first.
