# frozen_string_literal: true

module ClerkSessionHelper
  def sign_in_as(user)
    allow_any_instance_of(ApplicationController).to receive(:clerk_session_user_id)
      .and_return(user.clerk_user_id)
  end

  def sign_in_with_shop(user: nil, shop: nil)
    user ||= create(:user, :with_shop)
    shop ||= user.active_shop
    sign_in_as(user)
    [user, shop]
  end
end

RSpec.configure do |config|
  config.include ClerkSessionHelper, type: :controller
  config.include ClerkSessionHelper, type: :request
end
