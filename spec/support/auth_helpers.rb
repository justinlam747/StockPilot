# frozen_string_literal: true

# Legacy auth helper — kept for backward compatibility with existing specs.
# New specs should use ClerkSessionHelper#sign_in_as or #sign_in_with_shop directly.
module AuthHelpers
  # Signs in a user whose active_shop is the given shop.
  # If the shop has no user, creates one and assigns it.
  def login_as(shop)
    user = shop.user
    unless user
      user = create(:user, :onboarded)
      shop.update!(user: user)
      user.update!(active_shop_id: shop.id)
    end
    sign_in_as(user)
  end
end

RSpec.configure do |config|
  config.include AuthHelpers, type: :controller
  config.include AuthHelpers, type: :request
end
