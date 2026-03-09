class AuthenticatedController < ActionController::API
  include ShopifyApp::EnsureHasSession

  before_action :set_tenant

  private

  def set_tenant
    shop_domain = current_shopify_session&.shop
    @current_shop = Shop.active.find_by!(shop_domain: shop_domain)
    ActsAsTenant.current_tenant = @current_shop
  rescue ActiveRecord::RecordNotFound
    render json: { error: "Shop not found or uninstalled" }, status: :unauthorized
  end

  def current_shop
    @current_shop
  end
end
