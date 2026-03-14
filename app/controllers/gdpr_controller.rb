class GdprController < ActionController::Base
  skip_before_action :verify_authenticity_token
  before_action :verify_shopify_hmac

  def customers_data_request
    shop = Shop.find_by(shop_domain: params[:shop_domain])
    return head :not_found unless shop

    AuditLog.record(action: "gdpr_customer_data_request", request: request,
                    metadata: { shop_domain: params[:shop_domain] })
    GdprCustomerDataJob.perform_later(shop.id, params[:customer]&.dig(:id))
    head :ok
  end

  def customers_redact
    shop = Shop.find_by(shop_domain: params[:shop_domain])
    return head :not_found unless shop

    AuditLog.record(action: "gdpr_customer_redact", request: request,
                    metadata: { shop_domain: params[:shop_domain] })
    GdprCustomerRedactJob.perform_later(shop.id, params[:customer]&.dig(:id))
    head :ok
  end

  def shop_redact
    shop = Shop.find_by(shop_domain: params[:shop_domain])
    return head :not_found unless shop

    AuditLog.record(action: "gdpr_shop_redact", request: request,
                    metadata: { shop_domain: params[:shop_domain] })
    GdprShopRedactJob.perform_later(shop.id)
    head :ok
  end

  private

  def verify_shopify_hmac
    body = request.body.read
    hmac = request.headers["HTTP_X_SHOPIFY_HMAC_SHA256"]
    return head :unauthorized unless hmac.present?
    digest = OpenSSL::HMAC.digest("sha256", ENV.fetch("SHOPIFY_API_SECRET"), body)
    expected = Base64.strict_encode64(digest)
    head :unauthorized unless ActiveSupport::SecurityUtils.secure_compare(expected, hmac)
  end
end
