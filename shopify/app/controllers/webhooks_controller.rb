class WebhooksController < ActionController::API
  before_action :verify_signature

  def receive
    payload = JSON.parse(request.raw_post)
    domain = request.headers['X-Shopify-Shop-Domain']
    return head :bad_request unless payload.is_a?(Hash)
    signed_domain = payload['myshopify_domain'] || payload['shop_domain']
    return head :bad_request if signed_domain && signed_domain != domain
    if %w[app_uninstalled shop_redact].include?(params[:topic]) && signed_domain.blank?
      return head :bad_request
    end
    shop = Shop.find_by(shop_domain: domain)
    return head :ok unless shop

    case params[:topic]
    when 'app_uninstalled'
      shop.with_lock do
        unless shop.uninstalled_at? || predates_install?(shop)
          shop.update!(access_token: '', refresh_token: nil, access_token_expires_at: nil,
                       refresh_token_expires_at: nil, reauthorization_required_at: nil, uninstalled_at: Time.current)
        end
      end
    when 'products_update'
      InventorySyncJob.perform_later(shop.id, shop.installation_id) unless shop.uninstalled_at?
    when 'products_delete'
      shop.with_lock { shop.products.where(shopify_product_id: payload.fetch('id')).update_all(deleted_at: Time.current) }
    when 'shop_redact'
      redact_shop(shop)
    end
    # No customer records or customer identifiers are stored by the connector.
    head :ok
  rescue JSON::ParserError, KeyError, ArgumentError
    head :bad_request
  end

  private

  def verify_signature
    expected = OpenSSL::HMAC.base64digest('SHA256', ENV.fetch('SHOPIFY_API_SECRET'), request.raw_post)
    valid = ActiveSupport::SecurityUtils.secure_compare(expected, request.headers['X-Shopify-Hmac-Sha256'].to_s)
    return head :unauthorized unless valid
    topic = request.headers['X-Shopify-Topic'].to_s.tr('/', '_')
    head :bad_request unless topic == params[:topic] && request.headers['X-Shopify-Shop-Domain'].present?
  end

  def predates_install?(shop)
    triggered_at = request.headers['X-Shopify-Triggered-At']
    triggered_at.present? && Time.iso8601(triggered_at) < shop.installed_at
  end

  def redact_shop(shop)
    shop.with_lock do
      return unless shop.uninstalled_at?
      return if predates_install?(shop)
      # Older installations also kept audit records with a non-cascading shop foreign key.
      if Shop.connection.data_source_exists?('audit_logs')
        Shop.connection.exec_delete(Shop.sanitize_sql_array(['DELETE FROM audit_logs WHERE shop_id = ?', shop.id]))
      end
      shop.destroy!
    end
  end
end
