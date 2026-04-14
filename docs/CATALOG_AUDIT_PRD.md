# Catalog Audit PRD

## Document Status

- Status: active working PRD
- Product name: Catalog Audit
- Product type: lean Shopify app
- Primary intent: portfolio-quality product with one clear merchant workflow

## Executive Summary

Catalog Audit is a narrow Shopify app that helps a merchant inspect the quality of their store catalog.

The app connects to a Shopify store, runs a product and variant sync, computes audit issues from the synced data, and presents those issues in a simple review UI. Each issue should help the merchant answer one question quickly:

- what is wrong
- why it matters
- what product is affected
- where to click in Shopify to fix it

This product is intentionally smaller than a traditional inventory SaaS. It is not a restocking engine, a purchasing system, or a reporting suite. Its value is clarity, not breadth.

## Problem Statement

Many Shopify merchants have catalogs that become inconsistent over time because of:

- repeated imports
- manual edits by multiple teammates
- migrations from other systems
- marketplace/feed requirements
- incomplete setup during product creation

The result is a catalog with issues like:

- missing images
- duplicate SKUs
- missing SKUs
- blank vendor values
- blank product types
- missing or zero prices
- weak or placeholder titles

These issues reduce catalog quality and create downstream problems in:

- merchandising
- search and filtering
- sales channel readiness
- operations
- trust and conversion

Merchants often do not need another broad operations product. They need a focused audit layer that tells them what to fix first.

## Product Thesis

The strongest version of this product is:

- one store
- one sync path
- one audit engine
- one dashboard
- one issues list

The product should feel like a clean review tool, not a sprawling back-office platform.

## User Need

The core user need is:

- show me what is wrong with my catalog
- help me prioritize the problems
- let me jump directly to Shopify Admin to fix them

The user is not asking the app to run the business. The user is asking the app to expose catalog mistakes quickly.

## Target Users

### Primary Users

- Shopify merchants with growing catalogs
- operators responsible for catalog quality
- e-commerce managers reviewing store readiness

### Secondary Users

- agencies cleaning up a client catalog
- freelancers doing store audits
- product-data specialists preparing a store for growth or migration

## Ideal User Situations

- merchant imported products from a spreadsheet and wants to spot mistakes
- merchant has multiple people editing the catalog and wants consistency checks
- merchant is preparing for feed submission or ad campaigns
- merchant wants a simple quality pass without buying a large operations platform

## Goals

### Product Goals

- connect a Shopify store quickly
- run one obvious sync action
- compute useful audit issues from catalog data
- make the issue list easy to scan
- keep the app small, understandable, and maintainable

### Experience Goals

- merchant understands the app within minutes
- merchant can move from issue discovery to Shopify fix with minimal friction
- issue descriptions are plain and operationally useful

### Engineering Goals

- one task per service
- minimal route surface
- narrow feature set
- codebase trending toward sub-20k LOC

## Non-Goals

The app will not be responsible for:

- supplier management
- purchase orders
- inventory replenishment workflows
- low-stock alerting as a product area
- weekly reports
- AI-generated procurement flows
- multi-store workspace management
- generic store consulting across every possible Shopify concern
- full SEO platform behavior
- auto-fixing catalog data in v1

## Core Value Proposition

Catalog Audit helps a merchant spot high-impact catalog quality problems and fix them faster.

The promise is not automation. The promise is visibility and prioritization.

## User Stories

1. As a merchant, I want to connect my Shopify store and immediately see whether my catalog has obvious quality problems.
2. As a merchant, I want issue counts by severity so I know what to fix first.
3. As a merchant, I want to search issues by title or SKU so I can locate specific products quickly.
4. As a merchant, I want to click from an issue directly into Shopify Admin.
5. As a merchant, I want the app to stay focused and not overwhelm me with unrelated workflows.

## Core Workflow

1. Merchant lands on the app.
2. Merchant opens settings or the connection CTA.
3. Merchant submits a Shopify domain.
4. Merchant completes Shopify OAuth.
5. App stores the connected shop and returns the merchant to the dashboard.
6. Merchant runs a sync.
7. App syncs products and variants.
8. App computes audit issues from local data.
9. Merchant reviews dashboard summary.
10. Merchant opens the issues page.
11. Merchant filters or searches.
12. Merchant clicks through to Shopify Admin to fix a product.

## MVP Scope

### In Scope

- Shopify OAuth connection
- one sync trigger
- local persistence of products and variants
- computed audit issues
- dashboard summary cards
- issues list
- severity filtering
- text search by title or SKU
- Shopify Admin deep links
- simple settings page

### Out of Scope

- issue history timeline
- issue dismissal as a core workflow
- issue assignments
- collaboration comments
- exports beyond a possible later CSV
- automated fixes
- AI-written product content
- supplier, purchase order, and reporting workflows

## Detailed Issue Taxonomy

### Critical

#### Duplicate SKU

Definition:

- more than one variant in the connected store shares the same non-blank SKU

Why it matters:

- breaks catalog clarity
- creates operational confusion
- can hurt integrations and feeds

Required output:

- issue title
- duplicated SKU value
- affected product title
- variant reference if present
- Shopify Admin link

#### Missing Or Zero Price

Definition:

- variant price is blank or `<= 0`

Why it matters:

- blocks expected merchandising behavior
- makes the product look incomplete
- can create customer trust issues

Required output:

- issue title
- product title
- variant SKU if present
- clear explanation that price must be set to a positive value

### Warning

#### Missing Product Image

Definition:

- product has no primary image URL

Why it matters:

- weakens merchandising
- lowers product clarity
- makes the storefront feel incomplete

#### Blank Vendor

Definition:

- product vendor is nil or blank

Why it matters:

- reduces consistency
- weakens filtering and organization

#### Blank Product Type

Definition:

- product type is nil or blank

Why it matters:

- weakens organization and downstream reporting

#### Missing SKU

Definition:

- variant SKU is nil or blank

Why it matters:

- creates ambiguity in operations and integrations

#### Weak Title

Definition:

- product title is very short or obviously non-descriptive

Initial rule:

- title length under 6 characters

Why it matters:

- makes the catalog harder to scan
- often signals incomplete product setup

## Functional Requirements

### Connection

- settings page must support the no-store-connected state
- merchant can enter either `store-name` or `store-name.myshopify.com`
- app must normalize the domain before OAuth redirect
- OAuth callback must persist the shop domain and token
- current connected shop must be stored in session for app navigation

### Sync

- dashboard must expose one sync action
- sync must use the existing Shopify connection
- sync must persist products and variants idempotently
- sync must update `synced_at`
- sync must not depend on old onboarding or demo flows

### Audit Engine

- audit logic must live in one service
- audit logic must work from local product and variant data
- audit issues must be computed fresh from current catalog state
- issue output must be consistent across dashboard and issues page
- issue severity must be deterministic
- issue codes must be explicit and stable

### Dashboard

- show products scanned
- show variants tracked
- show total issue count
- show critical issue count
- show warning issue count
- show catalog coverage percentage
- show recent issues
- show last sync state

### Issues Page

- show all computed issues
- support severity filtering
- support search by product title or SKU
- render issue title and detail
- show variant SKU when available
- provide a Shopify Admin link

### Settings

- if no store is connected, show a connect form
- if a store is connected, show connected shop information
- keep editable settings minimal
- timezone is acceptable as a minimal retained setting

## UX Principles

- one primary workflow only
- reduce cognitive overhead
- prefer plain language over internal jargon
- present useful issue context without turning each issue into a separate complex detail page
- reuse the existing app UI system where possible

## Technical Principles

- one task per service
- avoid duplicated logic across controllers
- keep route surface intentionally small
- delete dead product surface instead of simply hiding it
- prefer computed audit behavior over a sprawling side-system architecture

## Architecture Direction

### Keep

- Shopify OAuth
- `Shop`, `Product`, and `Variant`
- one sync job
- one audit service
- one dashboard
- one issues controller/view surface

### Transition Away From

- inventory-first UX
- onboarding flow
- imports flow
- supplier system
- purchase order system
- demo mode
- vision/blog product surface
- Clerk-specific product behavior in the main flow
- alerting/reporting subsystems as core product concepts

## Data Requirements

### Shop

Required fields:

- shop domain
- access token
- synced_at
- settings

### Product

Required fields:

- shopify product id
- title
- product type
- vendor
- status
- image URL

### Variant

Required fields:

- shopify variant id
- SKU
- title
- price

## Success Metrics

### Product Metrics

- merchant can complete connection successfully
- merchant can run sync successfully
- merchant sees issue list immediately after sync
- issue list is small enough to scan but useful enough to act on

### Portfolio Metrics

- reviewer can understand the app quickly
- repo tells one product story
- codebase complexity visibly trends downward

## Acceptance Criteria

- merchant can connect a store from settings
- dashboard does not advertise old inventory product areas
- issues page shows computed catalog issues
- duplicate SKU issues are detected correctly
- missing image issues are detected correctly
- missing or zero price issues are detected correctly
- blank vendor and blank product type issues are detected correctly
- weak-title issues are detected using the current rule
- each issue can link to the relevant product in Shopify Admin

## Risks

- old inventory code may remain in the repo and confuse the product story
- too many audit rules can widen scope too early
- old auth and onboarding assumptions can keep leaking into the main flow
- if issue logic is split across multiple layers, the app will become harder to explain

## Open Questions

- should the app persist audit issues later, or continue computing them dynamically in the lean version?
- should CSV export be part of v1 or deferred?
- should weak-title logic become more opinionated later, or stay intentionally simple?

## Next Product Steps

- remove remaining inventory-era models and services from the active product path
- trim old tests and docs to match the audit product
- decide whether to add one or two more high-signal audit rules without broadening scope
