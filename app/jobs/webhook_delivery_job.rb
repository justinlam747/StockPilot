class WebhookDeliveryJob < ApplicationJob
  queue_as :webhooks

  retry_on Net::OpenTimeout, wait: :polynomially_longer, attempts: 5
  retry_on Net::ReadTimeout, wait: :polynomially_longer, attempts: 5

  def perform(endpoint_id, payload_json)
    endpoint = WebhookEndpoint.find(endpoint_id)

    uri = URI.parse(endpoint.url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == "https"
    http.open_timeout = 10
    http.read_timeout = 10

    request = Net::HTTP::Post.new(uri.path.presence || "/")
    request["Content-Type"] = "application/json"
    request.body = payload_json

    response = http.request(request)

    endpoint.update!(
      last_fired_at: Time.current,
      last_status_code: response.code.to_i
    )

    unless response.is_a?(Net::HTTPSuccess)
      raise "Webhook delivery failed with status #{response.code}"
    end
  end
end
