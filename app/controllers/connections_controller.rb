# frozen_string_literal: true

# Handles Shopify OAuth for connecting a store to a user account.
class ConnectionsController < ApplicationController
  skip_before_action :require_shop_connection

  def shopify_connect
    shop_domain = "#{params[:shop_domain].strip.downcase}.myshopify.com"
    session[:connecting_shop] = shop_domain
    redirect_to "/auth/shopify?shop=#{shop_domain}", allow_other_host: true
  end

  def shopify_callback
    auth = request.env['omniauth.auth']
    shop = upsert_shop(auth)

    current_user.update!(active_shop_id: shop.id)
    AuditLog.record(action: 'shop_connected', shop: shop, request: request,
                    metadata: { user_id: current_user.id })

    if session.delete(:onboarding_return)
      current_user.update!(onboarding_step: 3)
      redirect_to onboarding_step_path(step: 3)
    else
      redirect_to '/dashboard', notice: 'Shopify store connected!'
    end
  end

  def failure
    AuditLog.record(action: 'shop_connection_failed', request: request,
                    metadata: { reason: params[:message], user_id: current_user&.id })
    redirect_back fallback_location: '/settings', alert: "Connection failed: #{params[:message]}"
  end

  def shopify_disconnect
    shop = current_user.shops.find(params[:id])
    shop.update!(uninstalled_at: Time.current)

    if current_user.active_shop_id == shop.id
      next_shop = current_user.shops.active.where.not(id: shop.id).first
      current_user.update!(active_shop_id: next_shop&.id)
    end

    redirect_to '/settings', notice: 'Store disconnected.'
  end

  private

  def upsert_shop(auth)
    # Check if this shop is already owned by another user
    existing = Shop.find_by(shop_domain: auth.uid)
    if existing && existing.user_id && existing.user_id != current_user.id
      raise ActiveRecord::RecordInvalid, 'This store is already connected to another account'
    end

    shop = Shop.find_or_initialize_by(shop_domain: auth.uid)
    shop.user = current_user
    shop.access_token = auth.credentials.token
    shop.installed_at ||= Time.current
    shop.uninstalled_at = nil
    shop.save!
    shop
  end
end
