# Agent Workboard

## Default Worker Lanes

1. Shell/Auth/Routes/Layout
2. Domain/Models/Audit Service
3. Shopify Sync/Webhooks/Jobs
4. Dashboard/Issues/Settings/Landing UI
5. Cleanup/Tests/Docs

## Current Round

- round status: integrated and critic-reviewed
- critic status: findings resolved

## Round 1 Worker Assignments

### Worker 1

- nickname: Aristotle
- area: shell/auth/config/docs cleanup
- owned paths:
  - `CLAUDE.md`
  - `config/application.rb`
  - `config/initializers/clerk.rb`
  - `config/initializers/rack_attack.rb`
  - `README.md`
  - `docs/SECURITY_COMPLIANCE.md`
  - `docs/TESTING_CHECKLIST.md`

### Worker 2

- nickname: James
- area: domain/model cleanup
- owned paths:
  - `app/models/shop.rb`
  - `app/models/product.rb`
  - `app/models/variant.rb`
  - `app/models/alert.rb`
  - `app/services/catalog/audit_service.rb`

### Worker 3

- nickname: Nash
- area: Shopify sync/webhooks/jobs
- owned paths:
  - `app/jobs/inventory_sync_job.rb`
  - `app/services/inventory/persister.rb`
  - `app/services/shopify/inventory_fetcher.rb`
  - `app/services/shopify/graphql_client.rb`
  - `app/services/shopify/webhook_registrar.rb`
  - `app/controllers/webhooks_controller.rb`

### Worker 4

- nickname: Peirce
- area: active UI/controller polish
- owned paths:
  - `config/routes.rb`
  - `app/controllers/application_controller.rb`
  - `app/controllers/alerts_controller.rb`
  - `app/controllers/dashboard_controller.rb`
  - `app/controllers/settings_controller.rb`
  - `app/views/alerts/*`
  - `app/views/dashboard/index.html.erb`
  - `app/views/landing/index.html.erb`
  - `app/views/settings/show.html.erb`
  - `app/views/shared/_sidebar.html.erb`
  - `app/views/shared/_connect_banner.html.erb`
  - `app/views/layouts/application.html.erb`
  - `app/views/layouts/landing.html.erb`

### Worker 5

- nickname: Nietzsche
- area: cleanup/tests/docs
- owned paths:
  - `spec/**/*`
  - `docs/superpowers/**/*`
  - `shopify-inventory-spec.md`
  - `GSD-PLAN.md`
  - `TECHNICAL_DECISIONS.md`
  - `docs/orchestration/*`

## Ownership Notes

- Keep worker ownership disjoint.
- Do not let two workers edit the same file in one round unless a manual integration plan exists.

## Changed Files Tracking

- integrated worker 1 shell/auth/config/docs cleanup
- integrated worker 2 domain/model and audit-service cleanup
- integrated worker 3 sync/webhook/job narrowing
- integrated worker 4 dashboard/issues/settings/landing polish
- deleted stale inventory-era spec surfaces under `spec/`
- deleted old planning docs in `docs/superpowers/`
- deleted `shopify-inventory-spec.md` and `GSD-PLAN.md`
- rewrote `TECHNICAL_DECISIONS.md`
- updated `spec/requests/security_headers_html_spec.rb`
- updated `spec/requests/rate_limiting_spec.rb`
- made `ApplicationController` resilient when `ShopifyApp::EnsureHasSession` is unavailable in test boot
- updated `docs/orchestration/ACTIVE_CONTEXT.md`
- updated `docs/orchestration/AGENT_WORKBOARD.md`
- updated `docs/orchestration/CRITIC_LOG.md`

## Remaining High-Value Work

- continue deleting remaining unused lower-layer code to approach the sub-20k LOC target
- rewrite or remove legacy inventory-era seeds and lower-layer jobs/services
- rename compatibility-era surfaces such as `AlertsController` when the next refactor tranche touches routing
