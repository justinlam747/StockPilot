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
  # Rate limiting for the lean Catalog Audit workflow.
  class Attack
    # Prefer the connected shop for merchant throttling, then fall back to
    # legacy local-auth session data, then IP for anonymous requests.
    SHOP_OR_IP = lambda do |req|
      session = req.env['rack.session'] || {}
      session['shopify_domain'] || session[:shopify_domain] ||
        req.env['clerk']&.try(:[], 'user_id') ||
        req.env['clerk']&.user_id ||
        req.ip
    end

    throttle('catalog/shop', limit: 60, period: 1.minute) do |req|
      SHOP_OR_IP.call(req) unless req.path.start_with?('/assets')
    end

    # Manual syncs are the only expensive write path in the lean product.
    throttle('catalog/sync/shop', limit: 10, period: 1.minute) do |req|
      SHOP_OR_IP.call(req) if req.path == '/sync' && req.post?
    end

    throttle('auth/ip', limit: 10, period: 5.minutes) do |req|
      req.ip if req.path.start_with?('/auth') || req.path.start_with?('/connections')
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
