# frozen_string_literal: true

# Receives and dispatches Shopify webhook events with HMAC verification.
class WebhooksController < ApplicationController
  skip_before_action :verify_authenticity_token
  before_action :verify_shopify_hmac

  def receive
    topic = params[:topic]
    shop_domain = request.headers['X-Shopify-Shop-Domain']
    AuditLog.record(action: 'webhook_received', metadata: { topic: topic, shop_domain: shop_domain })
    dispatch_webhook(topic, shop_domain)
    head :ok
  end

  private

  def dispatch_webhook(topic, shop_domain)
    case topic
    when 'app_uninstalled'   then handle_app_uninstalled(shop_domain)
    when 'products_update'   then handle_products_update(shop_domain)
    when 'products_delete'   then handle_products_delete(shop_domain)
    else Rails.logger.warn("[Webhook] Unhandled topic: #{topic}")
    end
  end

  def webhook_body
    @webhook_body ||= request.body.read
  end

  # HMAC VERIFICATION — how Shopify webhooks prove they're authentic:
  #
  # 1. Shopify creates a hash of the webhook body using our shared secret
  # 2. Shopify sends that hash in the X-Shopify-Hmac-SHA256 header
  # 3. We create our own hash of the body using the same secret
  # 4. If the hashes match, the webhook is genuine (not forged)
  #
  # This prevents attackers from sending fake webhooks to our endpoint.
  # secure_compare prevents timing attacks (comparing strings in constant time).
  #
  def verify_shopify_hmac
    hmac = request.headers['HTTP_X_SHOPIFY_HMAC_SHA256']
    return head :unauthorized if hmac.blank?

    digest = OpenSSL::HMAC.digest('sha256', ENV.fetch('SHOPIFY_API_SECRET'), webhook_body)
    expected = Base64.strict_encode64(digest)
    return if ActiveSupport::SecurityUtils.secure_compare(expected, hmac)

    AuditLog.record(action: 'webhook_hmac_failed', request: request)
    head :unauthorized
  end

  def handle_app_uninstalled(shop_domain)
    shop = Shop.find_by(shop_domain: shop_domain)
    shop&.update!(uninstalled_at: Time.current, access_token: '')
  end

  def handle_products_update(shop_domain)
    shop = Shop.active.find_by(shop_domain: shop_domain)
    return unless shop

    ActsAsTenant.with_tenant(shop) do
      Inventory::Persister.new(shop).upsert_single_product(JSON.parse(webhook_body), source: :webhook)
    end
  end

  def handle_products_delete(shop_domain)
    shop = Shop.active.find_by(shop_domain: shop_domain)
    return unless shop

    data = JSON.parse(webhook_body)
    ActsAsTenant.with_tenant(shop) do
      product = Product.find_by(shopify_product_id: data['id'])
      product&.update!(deleted_at: Time.current)
    end
  end
end
