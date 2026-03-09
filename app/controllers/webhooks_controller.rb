class WebhooksController < ActionController::API
  include ShopifyApp::WebhookVerification

  def receive
    # Implementation will go here
    head :ok
  end
end
