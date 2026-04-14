# Catalog Audit

A lean Shopify app that connects a store, runs a catalog sync, and surfaces product-quality issues in one review workflow.

## Product Direction

This repo is being reduced toward a smaller hiring artifact:

- one Shopify connection flow
- one sync path
- one issue review surface
- fewer services and fewer moving parts
- a codebase that stays readable and trends toward sub-20k LOC

The goal is to keep the codebase readable and materially smaller than the original inventory-heavy app.

## Current Focus

- Shopify OAuth
- product and variant sync
- issue review dashboard
- issue list
- settings and operational basics

## Lean Stack Principles

- one task per service
- avoid duplicate business logic
- prefer read-heavy workflows
- cut side quests before adding new features

## Running Locally

```bash
bundle install
bundle exec rails db:prepare
bundle exec rails server
```

Run Sidekiq only when testing async sync paths:

```bash
bundle exec sidekiq -C config/sidekiq.yml
```

## Core Environment Variables

- `SHOPIFY_API_KEY`
- `SHOPIFY_API_SECRET`
- `SHOPIFY_APP_URL`
- `DATABASE_URL`
- `REDIS_URL`
