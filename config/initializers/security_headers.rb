# frozen_string_literal: true

Rails.application.config.action_dispatch.default_headers = {
  'Strict-Transport-Security' => 'max-age=31536000; includeSubDomains',
  'X-Content-Type-Options' => 'nosniff',
  'Referrer-Policy' => 'strict-origin-when-cross-origin',
  'Permissions-Policy' => 'camera=(), microphone=(), geolocation=()',
  'Content-Security-Policy' => [
    "default-src 'self'",
    "script-src 'self' 'unsafe-inline' https://unpkg.com https://cdn.jsdelivr.net https://cdn.shopify.com",
    "style-src 'self' 'unsafe-inline' https://unpkg.com https://fonts.googleapis.com https://cdn.shopify.com",
    "img-src 'self' data: https://cdn.shopify.com",
    "font-src 'self' https://fonts.gstatic.com",
    "connect-src 'self' https://*.shopify.com",
    "worker-src 'self' blob:",
    "frame-src 'self' https://*.shopify.com",
    "frame-ancestors 'self' https://*.myshopify.com https://admin.shopify.com",
    "base-uri 'self'",
    'form-action *'
  ].join('; ')
}
