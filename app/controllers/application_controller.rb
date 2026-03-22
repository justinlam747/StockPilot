# frozen_string_literal: true

# Base controller providing Clerk authentication, tenant scoping, and cache helpers.
class ApplicationController < ActionController::Base
  before_action :require_clerk_session
  before_action :require_onboarding
  before_action :require_shop_connection
  before_action :set_tenant
  before_action :enforce_demo_read_only

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
    return @current_user = nil unless clerk_user_id

    @current_user = User.active.find_by(clerk_user_id: clerk_user_id)

    # If we have a valid Clerk session but no User record yet (webhook race condition),
    # create the user on-demand from session claims.
    unless @current_user
      clerk_claims = request.env['clerk'] || {}
      if clerk_claims['user_id'].present? || clerk_claims['sub'].present?
        @current_user = User.create_or_find_by!(clerk_user_id: clerk_user_id) do |u|
          u.email = clerk_claims['email'] || "#{clerk_user_id}@pending.clerk"
          u.name = [clerk_claims['first_name'], clerk_claims['last_name']].compact.join(' ').presence
          u.onboarding_step = 1
        end
      end
    end

    @current_user
  end
  helper_method :current_user

  def current_shop
    return @current_shop if defined?(@current_shop)

    if demo_mode?
      @current_shop = Shop.find_by(id: session[:demo_shop_id])
    else
      @current_shop = current_user&.active_shop
    end
  end
  helper_method :current_shop

  def set_tenant
    ActsAsTenant.current_tenant = current_shop
  end

  def demo_mode?
    session[:demo_mode].present? && session[:demo_shop_id].present?
  end
  helper_method :demo_mode?

  def enforce_demo_read_only
    return unless demo_mode?
    return if request.get? || request.head?
    return if controller_name == 'dashboard' && action_name == 'toggle_demo'
    return if controller_name == 'dashboard' && action_name == 'run_agent'

    redirect_to '/dashboard', alert: 'Demo mode is read-only'
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
