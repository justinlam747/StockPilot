# Deploying StockPilot

Two pieces: Fly.io for the Rails web + Sidekiq worker; Neon (Postgres) and Upstash (Redis) stay as-is.

## One-time setup

```bash
# Install Fly CLI (Windows)
iwr https://fly.io/install.ps1 -useb | iex
fly auth login

# Create the app (no deploy yet — config already lives in fly.toml)
fly launch --no-deploy --copy-config
```

## Set secrets

```bash
fly secrets set \
  SHOPIFY_API_KEY=... \
  SHOPIFY_API_SECRET=... \
  SHOPIFY_APP_URL=https://stockpilot.fly.dev \
  DATABASE_URL='postgresql://...neon.tech/neondb?sslmode=require' \
  REDIS_URL='rediss://default:...upstash.io:6379' \
  SECRET_KEY_BASE="$(openssl rand -hex 64)" \
  RAILS_MASTER_KEY=... \
  SENDGRID_API_KEY=... \
  MAIL_FROM=noreply@yourdomain.com \
  SENTRY_DSN=...
```

Optional AI:

```bash
fly secrets set ANTHROPIC_API_KEY=... AI_PROVIDER=anthropic
```

## Deploy

```bash
fly deploy
```

The `release_command` in `fly.toml` runs `db:prepare` before each release. Web + worker share one Docker image; Fly runs them as separate processes.

## Custom domain

```bash
fly certs add stockpilot.yourdomain.com
fly ips list   # add A and AAAA records pointing at these IPs
```

Then update `SHOPIFY_APP_URL` and `shopify.app.toml` `application_url` + `redirect_urls` to the custom domain and redeploy.

## Custom-distribution install

In the Shopify Partner Dashboard → your app → Distribution → choose **Custom distribution**, generate an install link for the merchant store(s) you want to onboard. No app review.

## Smoke test

1. Open the install link, authorize on a dev store.
2. Check `fly logs` — you should see `AfterAuthenticateJob` enqueue, webhooks register, and `InventorySyncJob` complete.
3. Hit `/dashboard` — you should be embedded in Shopify Admin.
4. Trigger an agent run from `/agents` and accept a recommendation; verify the draft PO and supplier email body render.
