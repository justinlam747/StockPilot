---
name: new-issue
description: Create a well-structured GitHub Issue with description, acceptance criteria, and labels. Use when starting new work on a feature, bug, or chore.
user-invocable: true
---

## Create GitHub Issue

Create a GitHub Issue following project conventions.

### Steps

1. Ask the user for a brief description of the issue (if not provided as an argument).
2. Determine the issue type and select the appropriate label: `bug`, `feature`, `chore`, `ci`, `docs`, or `security`.
3. Draft the issue with:
   - **Clear title** (imperative mood, concise)
   - **Description** of the problem or feature
   - **Acceptance criteria** as a checklist
   - **Affected area** of the codebase
4. Show the draft to the user for approval before creating.
5. Create the issue using `gh issue create`.

### Template

```markdown
## Description
[What is this issue about?]

## Acceptance Criteria
- [ ] Criterion 1
- [ ] Criterion 2
- [ ] Criterion 3

## Affected Area
[e.g., Backend/Models, Frontend/Dashboard, Sidekiq Jobs]

## Notes
[Any additional context, links to PRD user stories, etc.]
```

### Example

```bash
gh issue create \
  --title "feat: Add supplier CRUD endpoints" \
  --label "feature" \
  --body "$(cat <<'EOF'
## Description
Implement REST API endpoints for supplier management (US-010).

## Acceptance Criteria
- [ ] GET /api/suppliers returns paginated list scoped to shop
- [ ] POST /api/suppliers creates a new supplier with validation
- [ ] PATCH /api/suppliers/:id updates supplier details
- [ ] DELETE /api/suppliers/:id soft-deletes a supplier

## Affected Area
Backend/Controllers, Backend/Models

## Notes
Related to US-010 in the PRD.
EOF
)"
```
