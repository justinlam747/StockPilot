# frozen_string_literal: true

require 'clerk'

# Only configure Clerk when both keys are present.
# This keeps the legacy local-auth path optional while the Shopify OAuth flow
# remains the primary merchant connection path.
clerk_secret_key = ENV.fetch('CLERK_SECRET_KEY', '')
clerk_publishable_key = ENV['CLERK_PUBLISHABLE_KEY'] || ENV['NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY'] || ''

if clerk_secret_key.start_with?('sk_') && clerk_publishable_key.start_with?('pk_')
  Clerk.configure do |config|
    config.secret_key = clerk_secret_key
    config.publishable_key = clerk_publishable_key

    # Exclude Shopify OAuth routes from Clerk middleware.
    # The middleware must not interfere with the OmniAuth state parameter.
    config.excluded_routes = %w[
      /auth/shopify /auth/shopify/callback /auth/failure
    ]
  end

  # Register middleware here (not in application.rb) because dotenv
  # hasn't loaded .env yet when application.rb runs.
  Rails.application.config.middleware.use Clerk::Rack::Middleware
end
