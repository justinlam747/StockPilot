class Rack::Attack
  # Throttle general API requests: 60 req/min per shop
  throttle("api/shop", limit: 60, period: 1.minute) do |req|
    if req.path.start_with?("/api/v1")
      # Use the Authorization bearer token to identify the shop
      req.env["HTTP_AUTHORIZATION"]&.split(" ")&.last
    end
  end

  # Throttle AI endpoints: 10 req/min per shop
  throttle("api/ai", limit: 10, period: 1.minute) do |req|
    if req.path.start_with?("/api/v1/ai")
      req.env["HTTP_AUTHORIZATION"]&.split(" ")&.last
    end
  end

  # Throttle webhook delivery: 100 req/min
  throttle("webhooks", limit: 100, period: 1.minute) do |req|
    if req.path.start_with?("/api/webhooks")
      req.ip
    end
  end

  self.throttled_responder = lambda do |_req|
    [429, { "Content-Type" => "application/json" }, [{ error: "Rate limit exceeded" }.to_json]]
  end
end
