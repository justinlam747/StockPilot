# frozen_string_literal: true

# Allow nil tenant on shop-optional routes (onboarding, account, connections).
# Controllers that require a shop enforce it via require_shop_connection.
ActsAsTenant.configure do |config|
  config.require_tenant = false
end
