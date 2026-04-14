# frozen_string_literal: true

# Handles Shopify OAuth for connecting a store to the app.
class ConnectionsController < ApplicationController
  def shopify_connect
    domain = params[:shop_domain].to_s.strip.downcase
    if domain.blank?
      redirect_to '/settings', alert: 'Please enter your store URL'
      return
    end

    shop_domain = domain.include?('.') ? domain : "#{domain}.myshopify.com"
    redirect_to "/auth/shopify?shop=#{shop_domain}", allow_other_host: true
  end

  def shopify_callback
    auth = request.env['omniauth.auth']
    shop = upsert_shop(auth)

    session[:shopify_domain] = shop.shop_domain
    AuditLog.record(action: 'shop_connected', shop: shop, request: request)
    redirect_to '/dashboard', notice: 'Shopify store connected!'
  rescue ActiveRecord::RecordInvalid => e
    redirect_to '/settings', alert: e.message
  end

  def failure
    AuditLog.record(action: 'shop_connection_failed', request: request,
                    metadata: { reason: params[:message] })
    redirect_back fallback_location: '/settings', alert: "Connection failed: #{params[:message]}"
  end

  def shopify_disconnect
    shop = Shop.find(params[:id])
    shop.update!(uninstalled_at: Time.current)
    session.delete(:shopify_domain) if session[:shopify_domain] == shop.shop_domain

    redirect_to '/settings', notice: 'Store disconnected.'
  end

  private

  def upsert_shop(auth)
    shop = Shop.find_or_initialize_by(shop_domain: auth.uid)
    shop.access_token = auth.credentials.token
    shop.installed_at ||= Time.current
    shop.uninstalled_at = nil
    shop.save!
    shop
  rescue ActiveRecord::RecordNotUnique
    Shop.find_by!(shop_domain: auth.uid)
  end
end
