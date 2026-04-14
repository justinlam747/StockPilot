# Active Context

## Product

Catalog Audit is a lean Shopify app focused on one workflow:

- connect store
- sync catalog
- compute issues
- review issues

## Current State

- the lean route shell is already in place
- the dashboard/issues/settings surface is framed around catalog audit rather than inventory ops
- stale inventory-era docs and specs have been removed in this round
- the surviving test surface is now centered on landing, health, webhooks, GDPR, security headers, rate limiting, and Shopify GraphQL
- `ApplicationController` now treats Shopify session middleware as optional in non-Shopify test boot paths
- the active OAuth scope is now limited to `read_products`
- the dashboard coverage metric now measures affected products instead of raw issue count
- direct request/service coverage now exists for connections, dashboard, issues, and `Catalog::AuditService`

## Work Completed In This Round

- worker 1 integrated shell/auth/config/docs cleanup across README, Clerk init, Rack::Attack, and security/testing docs
- worker 2 integrated the lean domain model for `Shop`, `Product`, `Variant`, `Alert`, and the single `Catalog::AuditService`
- worker 3 integrated the narrowed sync path with one catalog fetcher, one persister, one sync job, and webhook-triggered enqueueing
- worker 4 integrated the active catalog-audit UI shell across landing, dashboard, issues, settings, and shared layout/sidebar components
- worker 5 deleted the old inventory, supplier, purchase order, onboarding, demo, and vision spec/doc surface and replaced the technical decisions log
- request-spec boot no longer hard-fails when Shopify session middleware is unavailable
- removed the stray `User` dependency from the live `Shop` connection path and shop factory
- aligned `GdprShopRedactJob` with the lean catalog-audit data model
- made partial local spec runs possible by allowing `SIMPLECOV_DISABLE=1`
- resolved the critic findings around OAuth scope, dashboard summary math, and missing live-path test coverage

## Known Remaining Work

- continue trimming remaining inventory-oriented lower-layer code and any unused dependencies
- keep the repo moving toward the sub-20k LOC target
- reduce or replace legacy seed/demo data that still reflects the old inventory product
- decide whether to rename `AlertsController` to `IssuesController` once route/controller churn is worth it

## Current Risks

- the repo still contains legacy lower-layer code beyond the live catalog-audit workflow, so LOC is still above target
- a few surviving specs still target shared models/jobs and may need another alignment pass after deeper deletions
- the issues surface still uses `AlertsController` for compatibility, which is acceptable short-term but carries old terminology in the controller layer
- `db/seeds.rb` is still heavily inventory-era and no longer matches the lean product story

## Next Recommended Step

Delete or rewrite the remaining inventory-era lower layers in jobs, seeds, services, and models until the repo shape matches the catalog-audit PRD end to end.
