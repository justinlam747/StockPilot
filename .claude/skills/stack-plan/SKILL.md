---
name: stack-plan
description: Plan a Graphite PR stack for a user story. Breaks work into reviewable slices following CLAUDE.md sizing rules (200-300 lines each, max 500).
user-invocable: true
---

## PR Stack Planner

Given a user story (e.g., "US-010"), plan a Graphite PR stack following CLAUDE.md rules.

### Steps

1. Ask the user which user story or feature to plan (if not provided as an argument).
2. Read `shopify-inventory-spec.md` and any related files to understand the full scope.
3. Break the work into stacked PRs following the slice order:
   - **Schema/migration** — DB changes only
   - **Model + validations** — ActiveRecord model, scopes, associations
   - **Service/job logic** — business logic layer
   - **Controller/API** — endpoint wiring
   - **Frontend component** — React UI
   - **Tests** — can be bundled with each slice or as a final PR

### Sizing Rules

- Target **200-300 lines** of new logic per PR
- Hard max **500 lines** (justify if needed)
- Generated code, tests, and config don't count toward the limit
- Functions must be under **50 lines**

### Output Format

```
## PR Stack for US-XXX: [Story Title]

### PR 1: feat(US-XXX): add [table] migration + model
- Files: db/migrate/..., app/models/...
- Estimated lines: ~150
- Key changes: migration, model, associations, indexes

### PR 2: feat(US-XXX): add [feature] service
- Files: app/services/...
- Estimated lines: ~200
- Key changes: business logic, validations

### PR 3: ...

## Graphite Commands
gt create -m "feat(US-XXX): add [table] migration + model"
gt create -m "feat(US-XXX): add [feature] service"
...
gt submit
```
