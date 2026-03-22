# frozen_string_literal: true

require 'clerk'

# Only configure Clerk when a real secret key is present.
# In development and test, CLERK_SECRET_KEY may be blank — that's fine,
# as auth is bypassed via clerk_session_user_id fallback in ApplicationController.
clerk_secret_key = ENV.fetch('CLERK_SECRET_KEY', '')
if clerk_secret_key.start_with?('sk_')
  Clerk.configure do |config|
    config.secret_key = clerk_secret_key
  end
end
