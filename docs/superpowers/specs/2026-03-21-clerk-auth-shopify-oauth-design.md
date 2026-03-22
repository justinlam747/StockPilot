# Clerk Auth + Shopify OAuth — Design Spec

**Date:** 2026-03-21
**Status:** Approved

## Overview

Replace the current cookie-based Shopify OAuth login with a standalone SaaS authentication system using Clerk. Users create accounts via Clerk (email+password or Google), then connect their Shopify store via OAuth from an onboarding wizard. The app is a standalone website, not embedded in Shopify Admin.

## User Journey

1. User visits landing page → sees marketing page with "Sign Up" / "Log In" buttons
2. Clicks "Sign Up" → Clerk hosted sign-up (email+password or Google)
3. Email verified → redirect to `/onboarding/step/1`
4. Onboarding wizard (3 steps):
   - **Step 1:** Store name + category selection (apparel, home, electronics, other)
   - **Step 2:** Connect Shopify store via OAuth (with "Skip for now" option)
   - **Step 3:** Configure low-stock alert threshold + notification channels (in-app, email; Slack coming soon)
5. Redirect to `/dashboard` with live sync status
6. Returning users who completed onboarding go straight to `/dashboard`
7. Users who skipped Shopify connection see a persistent banner to connect

## Data Model Changes

### New: `users` table

| Column | Type | Notes |
|--------|------|-------|
| `id` | bigint | PK |
| `clerk_user_id` | string | UNIQUE, NOT NULL — Clerk's external user ID |
| `email` | string | Synced from Clerk, format validated |
| `name` | string | Synced from Clerk |
| `store_name` | string | From onboarding step 1 |
| `store_category` | string | From onboarding step 1 (apparel, home, electronics, other) |
| `onboarding_step` | integer | DEFAULT 1 — tracks wizard progress |
| `onboarding_completed_at` | timestamp | NULL until wizard finished |
| `active_shop_id` | bigint | FK → `shops.id`, nullable — currently selected shop |
| `deleted_at` | timestamp | Soft delete — set on Clerk user.deleted webhook |
| `created_at` | timestamp | |
| `updated_at` | timestamp | |

### Modified: `shops` table

| Change | Details |
|--------|---------|
| Add `user_id` | bigint FK → `users.id`, NOT NULL |
| Unique index | `(user_id, shop_domain)` — prevent duplicate store connections |

A User can own multiple Shops (connect multiple Shopify stores). Multi-tenancy stays on Shop — `acts_as_tenant :shop` is unchanged. The `access_token` NOT NULL constraint remains — Shop records are only created when OAuth completes successfully.

### Shop Lifecycle States

1. **No shop** — User signed up, hasn't connected Shopify (or skipped). No `Shop` row exists. `current_shop` is nil.
2. **Connected** — User completed OAuth. `Shop` row exists with `access_token` and `shop_domain`.
3. **Disconnected** — User disconnected store. `Shop` row kept with `uninstalled_at` set. Data preserved for reconnection.

### New: `User` model

```ruby
class User < ApplicationRecord
  has_many :shops, dependent: :nullify
  belongs_to :active_shop, class_name: 'Shop', optional: true

  validates :clerk_user_id, presence: true, uniqueness: true
  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :onboarding_step, inclusion: { in: 1..4 }

  scope :active, -> { where(deleted_at: nil) }

  def onboarding_completed?
    onboarding_completed_at.present?
  end
end
```

## Auth Architecture

### Request Flow (Every Authenticated Request)

1. Browser → Clerk JS automatically attaches session cookie
2. Rails → `clerk-sdk-ruby` middleware validates session
3. `ApplicationController` → `current_user` from Clerk session (via `clerk_user_id`)
4. `ApplicationController` → `current_shop` from `user.active_shop` (may be nil)
5. `ActsAsTenant` → scopes queries to `current_shop` (only on shop-required routes)

### Controller Authentication Layers

Three levels of access control:

1. **`require_clerk_session`** — User is authenticated via Clerk. Applied to all routes except landing page, webhooks, and health checks.
2. **`require_onboarding`** — User has completed onboarding. Redirects to `/onboarding/step/:current` if not. Applied to dashboard and all app routes.
3. **`require_shop_connection`** — User has an active shop connected. Shows "connect your store" banner or redirects if no shop. Applied to inventory, alerts, products, and all tenant-scoped routes.

```ruby
class ApplicationController < ActionController::Base
  before_action :require_clerk_session
  before_action :require_onboarding
  before_action :require_shop_connection
  before_action :set_tenant

  private

  def current_user
    @current_user ||= User.active.find_by(clerk_user_id: clerk_session.user_id)
  end

  def current_shop
    @current_shop ||= current_user&.active_shop
  end

  def set_tenant
    ActsAsTenant.current_tenant = current_shop
  end

  def require_clerk_session
    redirect_to root_path unless clerk_session&.valid?
  end

  def require_onboarding
    return unless current_user
    return if current_user.onboarding_completed?
    redirect_to onboarding_step_path(step: current_user.onboarding_step)
  end

  def require_shop_connection
    return unless current_user&.onboarding_completed?
    return if current_shop.present?
    # Allow access but show connect banner — don't block entirely
    @show_connect_banner = true
  end
end
```

### Controllers That Skip `require_shop_connection`

These controllers work without a tenant (shop-optional):

- `OnboardingController` — skips `require_onboarding` and `require_shop_connection`
- `ConnectionsController` — skips `require_shop_connection`
- `AccountController` — user profile/settings, no shop needed
- `Webhooks::ClerkController` — skips all auth (uses webhook signature verification)
- `LandingController` — skips all auth (public)

### `acts_as_tenant` Configuration

```ruby
# config/initializers/acts_as_tenant.rb
ActsAsTenant.configure do |config|
  config.require_tenant = false  # Allow nil tenant on shop-optional routes
end
```

Controllers that require tenant scoping enforce it via `require_shop_connection`. This replaces the previous implicit assumption that every user has a shop.

### Key Changes to `ApplicationController`

- Replace `require_login` (session-based) with `require_clerk_session`
- `current_user` — looked up via `clerk_user_id` from Clerk session
- `current_shop` — from `user.active_shop` (may be nil)
- Add `require_onboarding` and `require_shop_connection` layers
- `set_tenant` — allows nil tenant (controlled by `require_shop_connection`)

### What Gets Removed

- `OmniAuth::Builder` initializer for Shopify login (keep OmniAuth for store connection only)
- `AuthController#callback` as login handler (repurpose for Shopify store connection)
- `AuthController#install` (replaced by Clerk sign-up)
- `AuthController#dev_login` (replaced by Clerk dev instance)
- Cookie-based `session[:shop_id]` for authentication

### What Stays

- `acts_as_tenant :shop` on all models (now with `require_tenant = false`)
- Shopify OAuth for store **connection** (not login) — OmniAuth still used, with state param CSRF protection
- All existing controllers, views, jobs
- Sidekiq, Redis, Sentry config
- HMAC webhook verification
- `Rack::Attack` rate limiting
- All model validations and service objects

## Multi-Shop Switching

Users with multiple Shopify stores can switch between them:

```ruby
# Route
patch '/shops/:id/switch', to: 'shops#switch'

# ShopsController
def switch
  shop = current_user.shops.find(params[:id])
  current_user.update!(active_shop_id: shop.id)
  redirect_back fallback_location: dashboard_path
end
```

The `active_shop_id` on the User model persists the selection across sessions. Defaults to the first connected shop. The sidebar shows a shop switcher dropdown when the user has multiple shops.

## New Routes

```ruby
# Onboarding wizard
get '/onboarding', to: 'onboarding#index'  # Redirects to current step
get '/onboarding/step/:step', to: 'onboarding#show'
post '/onboarding/step/:step', to: 'onboarding#update'

# Shopify store connection (OAuth) — uses OmniAuth with state param
get '/connections/shopify/callback', to: 'connections#shopify_callback'
post '/connections/shopify', to: 'connections#shopify_connect'
delete '/connections/shopify/:id', to: 'connections#shopify_disconnect'

# Shop switching
patch '/shops/:id/switch', to: 'shops#switch'

# User account
get '/account', to: 'account#show'

# Clerk webhooks (user.created, user.updated, user.deleted)
post '/webhooks/clerk', to: 'webhooks/clerk#receive'
```

## New Controllers

### `OnboardingController`

- Skips `require_onboarding` and `require_shop_connection`
- `index` — redirects to `/onboarding/step/:current_step`
- `show` — renders the appropriate step (1, 2, or 3)
- `update` — processes step data, persists to User model, advances step
  - Step 1: saves `store_name` and `store_category` to `users` table
  - Step 2: initiates Shopify OAuth OR skips (advances to step 3)
  - Step 3: saves alert threshold to user settings, marks onboarding complete
- Redirects to `/dashboard` if onboarding already completed

### `ConnectionsController`

- Skips `require_shop_connection`
- `shopify_connect` — initiates Shopify OAuth via OmniAuth (generates cryptographic `state` parameter, stores in session for CSRF protection)
- `shopify_callback` — verifies `state` parameter, handles OAuth callback, creates Shop record with `access_token`, links to User, sets as `active_shop`
- `shopify_disconnect` — soft-disconnects store (sets `uninstalled_at`, keeps data)

### `Webhooks::ClerkController`

- Skips all auth (public endpoint)
- Verifies webhook signature using `svix` gem (validates `svix-id`, `svix-timestamp`, `svix-signature` headers)
- Idempotent handlers:
  - `user.created` — `User.find_or_create_by(clerk_user_id:)` with email/name
  - `user.updated` — updates email/name
  - `user.deleted` — soft deletes user (`deleted_at = Time.current`), does NOT cascade delete shops/data immediately
- Replay attack protection via timestamp validation (reject events older than 5 minutes)

## Landing Page

Replace current landing page with a marketing page featuring:
- Hero section explaining the product
- "Sign Up" button → Clerk sign-up
- "Log In" button → Clerk sign-in
- Feature highlights
- Uses Clerk's `<script>` tag for sign-in/sign-up components or redirects to Clerk hosted pages

## Onboarding UI Design

Approved design (see mockup in `.superpowers/brainstorm/`):

- Full-page, one-step-at-a-time flow with slide transitions
- Thin green progress bar at top (`#22c55e`)
- Black wireframe outline icons for categories (no emojis)
- Green primary buttons, green focus rings, green selection states
- Real brand logos: Gmail for email, Slack logo for Slack
- Success page with live sync status (pulsing dots)
- Inter font, 800 weight headings, conversational copy
- `stockpilot / setup` branding in top-left

**Note:** The onboarding pages use a standalone layout (no sidebar) that differs from the main app's White & Grey design system. Green accents match the dashboard's accent color palette. Once inside the app, the standard White & Grey system applies.

## Dependencies

### New Gems

- `clerk-sdk-ruby` — Clerk Ruby SDK for session validation and user management
- `svix` — Webhook signature verification for Clerk webhooks

### New JS

- Clerk JavaScript SDK (via CDN) — for sign-in/sign-up components on landing page

### Environment Variables

- `CLERK_PUBLISHABLE_KEY` — Clerk frontend key
- `CLERK_SECRET_KEY` — Clerk backend key
- `CLERK_WEBHOOK_SIGNING_SECRET` — for Svix webhook verification

## Disconnection / Uninstall Handling

- **User disconnects Shopify** → account and data kept, `uninstalled_at` set on Shop, can reconnect anytime
- **User deletes Clerk account** → Clerk webhook soft-deletes User (`deleted_at` set). Data preserved for 30-day grace period. Background job hard-deletes after grace period.
- **Shopify uninstall webhook** → marks shop as uninstalled but keeps user account

## Migration Strategy

1. Create `users` table with all columns
2. Add `user_id` column to `shops` (nullable initially)
3. Run migration task: for each existing Shop, create a User record and link
4. Add unique index on `(user_id, shop_domain)`
5. Set `user_id` NOT NULL on shops after backfill
6. No downtime required — all additive changes

## Security Considerations

- Clerk handles password hashing, MFA, brute force protection
- Clerk session tokens are validated server-side on every request
- Shopify access tokens remain encrypted via `encrypts :access_token`
- Shopify OAuth connection uses OmniAuth with cryptographic `state` parameter for CSRF protection
- Clerk webhook signatures verified via `svix` gem with timestamp validation
- Unique index on `(user_id, shop_domain)` prevents duplicate store connections
- Soft delete on user deletion with 30-day grace period before hard delete

### Security Header Updates (Standalone Mode)

Since the app is no longer embedded in Shopify Admin:

- `X-Frame-Options` → change from `ALLOWALL` to `DENY`
- `Content-Security-Policy frame-ancestors` → remove `*.myshopify.com` and `admin.shopify.com`, set to `'none'`
- `Content-Security-Policy script-src` → add Clerk JS CDN domain
- `Content-Security-Policy connect-src` → add Clerk API domain
- CORS origins → add Clerk's domain, remove Shopify admin origin
