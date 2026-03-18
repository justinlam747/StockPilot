# frozen_string_literal: true

# Base controller providing authentication, tenant scoping, and cache helpers.
class ApplicationController < ActionController::Base
  before_action :require_login
  before_action :set_tenant

  private

  def require_login
    redirect_to root_path, alert: 'Please log in' unless current_shop
  end

  def current_shop
    @current_shop ||= Shop.find_by(id: session[:shop_id])
  end
  helper_method :current_shop

  def set_tenant
    ActsAsTenant.current_tenant = current_shop
  end

  def shop_cache
    @shop_cache ||= Cache::ShopCache.new(current_shop)
  end
end
