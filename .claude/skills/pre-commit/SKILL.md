---
name: pre-commit
description: Verify a change locally before committing.
user-invocable: true
---

## Local verification

Choose the checks that exercise the files changed.

- Run `npm run build` for the local forecast app.
- Run `bundle exec rubocop --format simple` for Rails changes.
- Run the relevant request or integration specs with `bundle exec rspec`.
- Use the local browser to verify changes to user-facing flows.

Report which checks ran, the outcomes, and any failures to address before committing.
