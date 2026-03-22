# frozen_string_literal: true

require 'clerk'

# Only configure and enable Clerk when both keys are present.
# In development/test without Clerk keys, auth falls back to
# session[:dev_clerk_user_id] in ApplicationController.
clerk_secret_key = ENV.fetch('CLERK_SECRET_KEY', '')
clerk_publishable_key = ENV['CLERK_PUBLISHABLE_KEY'] || ENV['NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY'] || ''

if clerk_secret_key.start_with?('sk_') && clerk_publishable_key.start_with?('pk_')
  Clerk.configure do |config|
    config.secret_key = clerk_secret_key
    config.publishable_key = clerk_publishable_key

    # Exclude OmniAuth OAuth routes from Clerk middleware.
    # The Clerk middleware interferes with OmniAuth's session-based state
    # parameter (omniauth.state), causing callback failures.
    config.excluded_routes = %w[/auth/shopify /auth/shopify/callback /auth/failure /webhooks/clerk]
  end

  # Register middleware here (not in application.rb) because dotenv
  # hasn't loaded .env yet when application.rb runs.
  Rails.application.config.middleware.use Clerk::Rack::Middleware
end
