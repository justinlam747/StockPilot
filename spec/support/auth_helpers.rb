# frozen_string_literal: true

# Legacy auth helper — kept for backward compatibility with existing specs.
# New specs should use ClerkSessionHelper#sign_in_as or #sign_in_with_shop directly.
module AuthHelpers
  # Signs in a user whose active_shop is the given shop.
  # If the shop has no user, creates one and assigns it.
  def login_as(shop)
    user = shop.user || begin
      new_user = create(:user, :onboarded)
      shop.update!(user: new_user)
      new_user
    end
    updates = { active_shop_id: shop.id }
    unless user.onboarding_completed?
      updates[:onboarding_step] = 4
      updates[:onboarding_completed_at] = Time.current
    end
    user.update!(updates)
    sign_in_as(user)
  end
end

RSpec.configure do |config|
  config.include AuthHelpers, type: :controller
  config.include AuthHelpers, type: :request
end
