class WebhooksController < ActionController::API
  include ShopifyApp::WebhookVerification

  def receive
    topic = params[:topic]
    shop_domain = request.headers["X-Shopify-Shop-Domain"]
    body = request.body.read

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
