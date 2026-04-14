# Critic Log

## Round 0

- status: initialized
- findings: cleanup pass removed the bulk of the inventory-era spec/docs surface; no critic run yet
- unresolved risks:
  - a few generic specs and factories still remain for active shared models/jobs
  - other workers are still changing app-layer code, so test/document alignment may need a second pass
  - request specs currently fail to boot because `ApplicationController` references missing `ShopifyApp` in the active worktree
  - the cleanup still needs a final critic review before the round can be treated as closed

## Round 1 Pre-Critic Integration

- status: integrated
- findings:
  - all 5 worker lanes have been merged into the active worktree
  - the app now presents a single catalog-audit workflow across landing, connect, sync, dashboard, issues, and settings
  - the request-spec boot blocker around `ShopifyApp::EnsureHasSession` was fixed by making the include conditional
- unresolved risks:
  - the repo still contains legacy lower-layer code and dependencies beyond the live product path
  - controller naming still carries `AlertsController` compatibility terminology
  - focused request/spec verification still needs to run after integration
  - a fresh critic review is still required before this round is closed

## Round 1 Critic

- status: reviewed and resolved
- critic nickname: Pascal
- findings:
  - dashboard coverage was using raw issue count instead of affected-product count
  - OAuth scope still included legacy `read_inventory`
  - live catalog-audit paths lacked direct request/service coverage
  - continuity files were behind the actual integrated state
- resolutions:
  - `Catalog::AuditService#summary` now reports `affected_product_count` and the dashboard computes coverage from affected products
  - Shopify OmniAuth scope is now `read_products`
  - direct request/service specs now cover connections, dashboard, issues, audit summary, health, and GDPR
  - continuity files were updated after verification to reflect the resolved state
- residual risks:
  - the repo still contains legacy lower-layer code and inventory-era seeds outside the active catalog-audit path
  - compatibility naming remains in `AlertsController`
  - the repo still relies on targeted spec passes; a broader suite reshape is still needed as deletions continue

## Critic Requirements

Every critic round should check:

- PRD alignment
- checklist alignment
- integration gaps between worker lanes
- stale product-language drift
- missing tests for active behavior
- continuity-file updates
