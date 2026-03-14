class WebhooksController < ActionController::Base
  skip_before_action :verify_authenticity_token
  before_action :verify_shopify_hmac

  def receive
    topic = params[:topic]
    shop_domain = request.headers["X-Shopify-Shop-Domain"]
    body = request.body.read

    AuditLog.record(action: "webhook_received", metadata: { topic: topic, shop_domain: shop_domain })

    case topic
    when "app_uninstalled"
      handle_app_uninstalled(shop_domain)
    when "products_update"
      handle_products_update(shop_domain, JSON.parse(body))
    when "products_delete"
      handle_products_delete(shop_domain, JSON.parse(body))
    else
      Rails.logger.warn("[Webhook] Unhandled topic: #{topic}")
    end

    head :ok
  end

  private

  def verify_shopify_hmac
    body = request.body.read
    hmac = request.headers["HTTP_X_SHOPIFY_HMAC_SHA256"]
    return head :unauthorized unless hmac.present?
    digest = OpenSSL::HMAC.digest("sha256", ENV.fetch("SHOPIFY_API_SECRET"), body)
    expected = Base64.strict_encode64(digest)
    unless ActiveSupport::SecurityUtils.secure_compare(expected, hmac)
      AuditLog.record(action: "webhook_hmac_failed", request: request)
      head :unauthorized
    end
  end

  def handle_app_uninstalled(shop_domain)
    shop = Shop.find_by(shop_domain: shop_domain)
    shop&.update!(uninstalled_at: Time.current, access_token: "")
  end

  def handle_products_update(shop_domain, data)
    shop = Shop.active.find_by(shop_domain: shop_domain)
    return unless shop

    ActsAsTenant.with_tenant(shop) do
      Inventory::Persister.new(shop).upsert_single_product(data)
    end
  end

  def handle_products_delete(shop_domain, data)
    shop = Shop.active.find_by(shop_domain: shop_domain)
    return unless shop

    ActsAsTenant.with_tenant(shop) do
      product = Product.find_by(shopify_product_id: data["id"])
      product&.update!(deleted_at: Time.current)
    end
  end
end
