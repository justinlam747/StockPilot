# frozen_string_literal: true

Clerk.configure do |config|
  config.api_key = ENV.fetch('CLERK_SECRET_KEY', '')
end
