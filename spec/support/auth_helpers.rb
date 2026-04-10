# frozen_string_literal: true

# Test helper that simulates a merchant being signed in to a Shop via
# the Shopify OAuth session. Request specs call `login_as(shop)` in a
# `before` block and the controllers under test see that shop as the
# current_shop.
module AuthHelpers
  def login_as(shop)
    allow_any_instance_of(ApplicationController).to receive(:current_shop).and_return(shop)
    ActsAsTenant.current_tenant = shop
  end
end

RSpec.configure do |config|
  config.include AuthHelpers, type: :request
  config.include AuthHelpers, type: :controller
end
