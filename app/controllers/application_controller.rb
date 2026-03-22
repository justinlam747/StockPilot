# frozen_string_literal: true

# Base controller providing Clerk authentication, tenant scoping, and cache helpers.
class ApplicationController < ActionController::Base
  before_action :require_clerk_session
  before_action :require_onboarding
  before_action :require_shop_connection
  before_action :set_tenant

  private

  # Layer 1: Clerk session validation
  def require_clerk_session
    return if current_user

    redirect_to root_path, alert: 'Please sign in'
  end

  # Layer 2: Onboarding completion check
  def require_onboarding
    return unless current_user
    return if current_user.onboarding_completed?

    redirect_to onboarding_step_path(step: current_user.onboarding_step)
  end

  # Layer 3: Shop connection check (non-blocking — sets banner flag)
  def require_shop_connection
    return unless current_user&.onboarding_completed?
    return if current_shop.present?

    @show_connect_banner = true
  end

  def current_user
    return @current_user if defined?(@current_user)

    clerk_user_id = clerk_session_user_id
    @current_user = clerk_user_id ? User.active.find_by(clerk_user_id: clerk_user_id) : nil
  end
  helper_method :current_user

  def current_shop
    @current_shop ||= current_user&.active_shop
  end
  helper_method :current_shop

  def set_tenant
    ActsAsTenant.current_tenant = current_shop
  end

  def shop_cache
    @shop_cache ||= Cache::ShopCache.new(current_shop) if current_shop
  end

  # Extract Clerk user ID from session token.
  # clerk-sdk-ruby sets request.env['clerk'] with session claims.
  # Falls back to session-stored ID for dev_login in development.
  def clerk_session_user_id
    request.env.dig('clerk', 'user_id') ||
      request.env.dig('clerk', 'sub') ||
      (Rails.env.development? && session[:dev_clerk_user_id])
  end
end
