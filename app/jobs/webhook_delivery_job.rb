class WebhookDeliveryJob < ApplicationJob
  queue_as :webhooks

  retry_on Net::OpenTimeout, wait: :polynomially_longer, attempts: 5

  def perform(endpoint_id, payload)
    raise NotImplementedError
  end
end
