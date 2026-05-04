# frozen_string_literal: true

# Handles Shopify OAuth callback — persists the access token for the
# connecting shop and signs the merchant into the session.
class ConnectionsController < ApplicationController
  def shopify_callback
    auth = request.env['omniauth.auth']
    shop = upsert_shop(auth)

    session[:shopify_domain] = shop.shop_domain
    session[:shop_id] = shop.id
    AuditLog.record(action: 'shop_connected', shop: shop, request: request)
    AfterAuthenticateJob.perform_later(shop_domain: shop.shop_domain)

    redirect_to '/dashboard', notice: 'Shopify store connected!'
  rescue ActiveRecord::RecordInvalid => e
    redirect_to root_path, alert: e.message
  end

  def failure
    AuditLog.record(action: 'shop_connection_failed', request: request,
                    metadata: { reason: params[:message] })
    redirect_to root_path, alert: "Connection failed: #{params[:message]}"
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
    # Race condition: another request connected this shop concurrently
    Shop.find_by!(shop_domain: auth.uid)
  end
end
