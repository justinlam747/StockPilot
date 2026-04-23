# Agent Monitoring Lessons

- Keep every agent-run lookup and execution tenant-scoped. `AgentRun` is `acts_as_tenant :shop`, controller lookups should rely on scoped `find`, and jobs must wrap execution in `ActsAsTenant.with_tenant(run.shop)` so parent/child runs and foreign-run access cannot leak across shops.
- The duplicate-run guards exist for two different races. `pg_advisory_xact_lock` in `Agents::Runner` serializes the "check for active run, then create queued run" path per shop, while `run.with_lock` in `AgentRunJob#claim_run!` stops multiple workers or retries from booting the same queued run twice.
- Correction runs are intentionally rule-aware, not open-ended re-plans. The monitor only extracts a few regex-driven filters from correction text (`ignore supplierless`, `only out-of-stock`, `only low-stock`), so operator guidance should stay short and explicit or it will be logged but not change behavior.
- Local verification is limited in this shell because `ruby` and `bundle` are unavailable. Observer follow-up here can inspect code and specs, but Rails validation still needs a Ruby-capable environment for commands like `bundle exec rspec`.
