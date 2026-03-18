# frozen_string_literal: true

Rack::Attack.cache.store = if Rails.env.test?
                             ActiveSupport::Cache::MemoryStore.new
                           else
                             ActiveSupport::Cache::RedisCacheStore.new(
                               url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/0'),
                               namespace: 'throttle',
                               pool: false
                             )
                           end

module Rack
  class Attack
    # Helper to extract shop_id from session for per-tenant throttling.
    # Falls back to IP for unauthenticated requests (auth, webhooks).
    SHOP_OR_IP = lambda do |req|
      req.env['rack.session']&.dig('shop_id') || req.ip
    end

    throttle('req/shop', limit: 60, period: 1.minute) do |req|
      SHOP_OR_IP.call(req) unless req.path.start_with?('/assets')
    end

    throttle('agents/shop', limit: 5, period: 1.minute) do |req|
      SHOP_OR_IP.call(req) if req.path == '/agents/run' && req.post?
    end

    throttle('po-draft/shop', limit: 5, period: 1.minute) do |req|
      SHOP_OR_IP.call(req) if req.path == '/purchase_orders/generate_draft' && req.post?
    end

    throttle('auth/ip', limit: 10, period: 5.minutes) do |req|
      req.ip if req.path.start_with?('/auth')
    end

    throttle('webhooks/ip', limit: 100, period: 1.minute) do |req|
      req.ip if req.path.start_with?('/webhooks')
    end

    self.throttled_responder = lambda do |_request|
      html = '<html><body><h1>429 Too Many Requests</h1><p>Retry later.</p></body></html>'
      [429, { 'Content-Type' => 'text/html', 'Retry-After' => '60' }, [html]]
    end
  end
end
