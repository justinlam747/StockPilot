# frozen_string_literal: true

# Base controller providing Shopify session authentication, tenant scoping, and cache helpers.
class ApplicationController < ActionController::Base
  include ShopifyApp::EnsureHasSession if defined?(ShopifyApp::EnsureHasSession)

  before_action :scope_queries_to_current_shop

  private

  def current_shop
    return @current_shop if defined?(@current_shop)

    @current_shop = Shop.find_by(shop_domain: session[:shopify_domain])
  end
  helper_method :current_shop

  def require_shop!
    return if current_shop

    redirect_to settings_path, alert: 'Connect a Shopify store first.'
  end

  def scope_queries_to_current_shop
    ActsAsTenant.current_tenant = current_shop
  end

  def shop_cache
    @shop_cache ||= Cache::ShopCache.new(current_shop) if current_shop
  end
end
