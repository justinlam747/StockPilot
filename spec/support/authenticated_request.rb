# Helper for authenticated API request specs
module AuthenticatedRequest
  def authenticate_shop(shop)
    # Stub the ShopifyApp session token verification
    session = ShopifyAPI::Auth::Session.new(
      shop: shop.shop_domain,
      access_token: shop.access_token
    )
    allow_any_instance_of(AuthenticatedController).to receive(:current_shopify_session).and_return(session)
  end
end

RSpec.configure do |config|
  config.include AuthenticatedRequest, type: :request
end
