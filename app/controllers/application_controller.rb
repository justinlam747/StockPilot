# frozen_string_literal: true

# Base controller providing Shopify session authentication, tenant scoping, and cache helpers.
class ApplicationController < ActionController::Base
  before_action :scope_queries_to_current_shop

  private

  def current_shop
    return @current_shop if defined?(@current_shop)

    @current_shop = Shop.find_by(shop_domain: session[:shopify_domain])
  end
  helper_method :current_shop

  # Before-action used by authenticated controllers to short-circuit
  # requests when no Shopify store is connected to the session.
  def require_shop!
    return if current_shop

    redirect_to root_path, alert: 'Please connect your Shopify store first.'
  end

  def scope_queries_to_current_shop
    ActsAsTenant.current_tenant = current_shop
  end

  def shop_cache
    @shop_cache ||= Cache::ShopCache.new(current_shop) if current_shop
  end
end
