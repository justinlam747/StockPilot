# Catalog Audit Checklist

## Purpose

This checklist tracks the implementation and cleanup work required to make Catalog Audit the real product of the repo.

## Product Alignment

- [x] Rename the top-level product narrative to Catalog Audit.
- [x] Reduce the live route surface to a lean workflow.
- [x] Keep the app centered on connect -> sync -> review.
- [ ] Remove old inventory language from every remaining user-facing screen.
- [ ] Remove old inventory language from every remaining internal doc.

## Core Workflow

### Connection

- [x] Show a no-store-connected state in settings.
- [x] Add a connect form for Shopify domain submission.
- [x] Normalize submitted domain values before redirecting to OAuth.
- [x] Store connected shop domain in session after callback.
- [ ] Verify disconnect flow still works correctly for the lean product.
- [ ] Add a request spec for connect form -> OAuth redirect behavior.

### Sync

- [x] Expose one sync action from the dashboard.
- [x] Keep one primary sync job entry point.
- [ ] Rename sync language from inventory sync to catalog sync where appropriate.
- [ ] Remove sync dependencies on old inventory-only side effects.
- [ ] Add a request or integration spec for sync trigger behavior.

### Audit

- [x] Create one audit service.
- [x] Compute issues from local product and variant data.
- [x] Feed dashboard from the audit service.
- [x] Feed issues page from the audit service.
- [ ] Add tests for every active audit rule.
- [ ] Ensure issue ordering is deterministic and intentional.

## Audit Rules

### Critical Rules

- [x] Detect duplicate SKU.
- [x] Detect missing or zero price.
- [ ] Add tests covering duplicate SKU edge cases.
- [ ] Add tests covering blank price and zero price separately.

### Warning Rules

- [x] Detect missing product image.
- [x] Detect blank vendor.
- [x] Detect blank product type.
- [x] Detect missing SKU.
- [x] Detect weak title.
- [ ] Add tests for missing image detection.
- [ ] Add tests for blank vendor detection.
- [ ] Add tests for blank product type detection.
- [ ] Add tests for missing SKU detection.
- [ ] Add tests for weak-title detection.

## Dashboard

- [x] Replace inventory KPI framing with catalog audit framing.
- [x] Show products scanned.
- [x] Show variants tracked.
- [x] Show total issue count.
- [x] Show critical and warning issue counts.
- [x] Show last sync state.
- [x] Show recent issues.
- [ ] Add a stronger empty state when no issues exist.
- [ ] Add a dashboard spec verifying summary values are consistent with audit output.

## Issues Page

- [x] Rename alerts surface to issues in the UI.
- [x] Support severity filtering.
- [x] Support search by title or SKU.
- [x] Show issue title and detail.
- [x] Show Shopify Admin link.
- [ ] Improve visual distinction between critical and warning rows.
- [ ] Add request specs for filter behavior.
- [ ] Add request specs for search behavior.
- [ ] Add request specs for pagination behavior.

## Settings Page

- [x] Support no-store-connected state.
- [x] Support connected-store state.
- [x] Keep settings minimal.
- [ ] Decide whether timezone still belongs in the lean version.
- [ ] Add request specs for settings update behavior.

## Navigation And Layout

- [x] Reduce sidebar to dashboard, issues, settings.
- [x] Remove live nav links to deleted feature areas.
- [x] Remove demo banner from main layout.
- [x] Remove Clerk script from active layout.
- [ ] Check for leftover unreachable layout partials and delete them.

## Controllers

- [x] Simplify `ApplicationController`.
- [x] Add `require_shop!` guard in the new shell.
- [x] Simplify `ConnectionsController`.
- [x] Simplify `DashboardController`.
- [x] Simplify `SettingsController`.
- [x] Reuse `AlertsController` temporarily as issues controller behavior.
- [ ] Rename `AlertsController` to `IssuesController`.
- [ ] Rename alert views folder to issues views folder.

## Routes

- [x] Keep root landing page.
- [x] Keep Shopify connection routes.
- [x] Keep dashboard route.
- [x] Keep sync route.
- [x] Keep issues route.
- [x] Keep settings route.
- [x] Keep health route.
- [x] Keep GDPR and webhook routes.
- [ ] Remove any stale route helper references in specs and views.

## Views And Assets

- [x] Replace landing page copy with catalog audit messaging.
- [x] Replace dashboard copy with catalog audit messaging.
- [x] Replace issues page copy with catalog audit messaging.
- [x] Replace settings page copy with catalog audit messaging.
- [x] Delete onboarding views.
- [x] Delete inventory views.
- [x] Delete import views.
- [x] Delete supplier views.
- [x] Delete purchase order views.
- [x] Delete vision view.
- [x] Delete onboarding/demo/vision JS and CSS assets.
- [ ] Remove unused images tied only to deleted product areas.

## Models And Services

### Keep And Refine

- [x] Keep `Shop`.
- [x] Keep `Product`.
- [x] Keep `Variant`.
- [x] Add `Catalog::AuditService`.
- [ ] Simplify `Shop` by removing inventory-only helpers later.
- [ ] Simplify `Product` by removing inventory-only scopes later.
- [ ] Simplify `Variant` by removing supplier and inventory-only associations later.

### Remove Or Replace

- [ ] Remove `Inventory::LowStockDetector` from the active product path.
- [ ] Remove `Notifications::AlertSender` from the active product path.
- [ ] Remove `InventorySnapshot` from the active product path.
- [ ] Remove `Supplier` from the active product path.
- [ ] Remove `PurchaseOrder` and related models from the active product path.
- [ ] Decide whether `Alert` remains as a compatibility layer or is deleted.

## Shopify Integration

- [x] Narrow OAuth scopes from the broader old product.
- [ ] Rename fetcher/persister classes from inventory-oriented naming to catalog-oriented naming.
- [ ] Remove inventory-level fields from the fetcher payload if not needed.
- [ ] Ensure webhook behavior matches the lean product story.
- [ ] Add integration tests for OAuth callback and sync.

## Docs

- [x] Create a Catalog Audit PRD.
- [x] Create a detailed implementation checklist.
- [x] Rewrite the root README to match the lean product.
- [ ] Archive or rewrite old superpowers docs.
- [ ] Archive or rewrite old testing checklist if it still reflects the inventory product.
- [ ] Remove or rewrite any remaining docs that pitch StockPilot as an inventory suite.

## Tests

- [ ] Add service specs for `Catalog::AuditService`.
- [ ] Add request specs for dashboard.
- [ ] Add request specs for issues filtering and search.
- [ ] Add request specs for settings connect state.
- [ ] Delete specs for deleted onboarding flows.
- [ ] Delete specs for deleted imports flow.
- [ ] Delete specs for deleted inventory pages.
- [ ] Delete specs for deleted suppliers and purchase orders.
- [ ] Delete specs for deleted vision flow.
- [ ] Re-measure LOC after spec cleanup.

## LOC Reduction

- [x] Cut unreachable routes.
- [x] Delete unreachable controllers/views/assets for major old features.
- [ ] Delete old specs tied to removed features.
- [ ] Delete old services tied to removed features.
- [ ] Delete old models tied to removed features.
- [ ] Re-measure total LOC after each deletion tranche.
- [ ] Continue until the repo is materially closer to sub-20k LOC.

## Final Quality Bar

- [ ] Reviewer can understand the app in under 10 minutes.
- [ ] Repo tells one product story only.
- [ ] One sync path remains.
- [ ] One audit engine remains.
- [ ] One issues review surface remains.
- [ ] Remaining code is readable enough to discuss confidently in an interview.
