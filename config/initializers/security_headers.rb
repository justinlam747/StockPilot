Rails.application.config.action_dispatch.default_headers.merge!(
  "Strict-Transport-Security" => "max-age=31536000; includeSubDomains",
  "X-Content-Type-Options" => "nosniff",
  "X-Frame-Options" => "ALLOWALL",
  "Content-Security-Policy" => "frame-ancestors https://*.myshopify.com https://admin.shopify.com",
  "Referrer-Policy" => "strict-origin-when-cross-origin",
  "Permissions-Policy" => "camera=(), microphone=(), geolocation=()"
)
