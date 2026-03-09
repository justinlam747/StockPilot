class GdprController < ActionController::API
  include ShopifyApp::WebhookVerification

  def customers_data_request
    head :ok
  end

  def customers_redact
    head :ok
  end

  def shop_redact
    head :ok
  end
end
