# frozen_string_literal: true

Rails.application.config.action_dispatch.default_headers = {
  'Strict-Transport-Security' => 'max-age=31536000; includeSubDomains',
  'X-Content-Type-Options' => 'nosniff',
  'X-Frame-Options' => 'ALLOWALL',
  'Referrer-Policy' => 'strict-origin-when-cross-origin',
  'Permissions-Policy' => 'camera=(), microphone=(), geolocation=()',
  'Content-Security-Policy' => [
    "default-src 'self'",
    "script-src 'self' https://unpkg.com",
    "style-src 'self' https://unpkg.com 'unsafe-inline'",
    "img-src 'self' data:",
    "font-src 'self'",
    "connect-src 'self'",
    'frame-ancestors https://*.myshopify.com https://admin.shopify.com',
    "base-uri 'self'",
    "form-action 'self' https://*.myshopify.com"
  ].join('; ')
}
