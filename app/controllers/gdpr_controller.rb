class GdprController < ActionController::API
  include ShopifyApp::WebhookVerification

  def customers_data_request
    payload = JSON.parse(request.body.read)
    Rails.logger.info("[GDPR] customers/data_request for shop #{payload['shop_domain']}")
    head :ok
  end

  def customers_redact
    payload = JSON.parse(request.body.read)
    shop = Shop.find_by(shop_domain: payload["shop_domain"])
    if shop
      customer_id = payload.dig("customer", "id")
      ActsAsTenant.with_tenant(shop) do
        Customer.where(shopify_customer_id: customer_id).destroy_all
      end
    end
    head :ok
  end

  def shop_redact
    payload = JSON.parse(request.body.read)
    shop = Shop.find_by(shop_domain: payload["shop_domain"])
    shop&.destroy!
    head :ok
  end
end
