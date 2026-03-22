# frozen_string_literal: true

# Standalone SaaS — no longer embedded in Shopify Admin.
# Only allow requests from our own app domain.
Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins ENV.fetch('SHOPIFY_APP_URL', 'https://localhost:3000')
    resource '*',
             headers: :any,
             methods: %i[get post put patch delete options head],
             credentials: true
  end
end
