# frozen_string_literal: true

Rails.application.config.action_dispatch.default_headers = {
  'Strict-Transport-Security' => 'max-age=31536000; includeSubDomains',
  'X-Content-Type-Options' => 'nosniff',
  'X-Frame-Options' => 'DENY',
  'Referrer-Policy' => 'strict-origin-when-cross-origin',
  'Permissions-Policy' => 'camera=(), microphone=(), geolocation=()',
  'Content-Security-Policy' => [
    "default-src 'self'",
    "script-src 'self' https://unpkg.com https://cdn.jsdelivr.net https://*.clerk.accounts.dev",
    "style-src 'self' https://unpkg.com https://fonts.googleapis.com 'unsafe-inline'",
    "img-src 'self' data: https://cdn.shopify.com https://img.clerk.com",
    "font-src 'self' https://fonts.gstatic.com",
    "connect-src 'self' https://*.clerk.accounts.dev",
    "frame-ancestors 'none'",
    "base-uri 'self'",
    "form-action *"
  ].join('; ')
}
