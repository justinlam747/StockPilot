# frozen_string_literal: true

# Handles Shopify OAuth callback, session management, and logout.
class AuthController < ApplicationController
  skip_before_action :require_login
  layout 'landing', only: :install

  def callback
    auth = request.env['omniauth.auth']
    reset_session
    shop = upsert_shop(auth)
    session[:shop_id] = shop.id
    AuditLog.record(action: 'login', shop: shop, request: request)
    redirect_to '/dashboard'
  end

  def failure
    AuditLog.record(action: 'login_failed', request: request,
                    metadata: { reason: params[:message] })
    redirect_to root_path, alert: "Authentication failed: #{params[:message]}"
  end

  def install
    # Renders a page with a form that POSTs to /auth/shopify (OmniAuth)
  end

  # Development-only: auto-login as the first shop in DB
  def dev_login
    return head :not_found unless Rails.env.development?

    shop = Shop.first
    return redirect_to root_path, alert: 'No shops. Run: rails db:seed' unless shop

    session[:shop_id] = shop.id
    redirect_to '/dashboard'
  end

  def destroy
    AuditLog.record(action: 'logout', shop: current_shop, request: request)
    reset_session
    redirect_to root_path
  end

  private

  def upsert_shop(auth)
    shop = Shop.find_or_initialize_by(shop_domain: auth.uid)
    shop.access_token = auth.credentials.token
    shop.installed_at ||= Time.current
    shop.save!
    shop
  end
end
