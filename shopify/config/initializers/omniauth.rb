Rails.application.config.middleware.use OmniAuth::Builder do
  provider :shopify, ENV.fetch('SHOPIFY_API_KEY'), ENV.fetch('SHOPIFY_API_SECRET'),
    scope: 'read_products,read_inventory', token_params: { expiring: 1 },
    callback_url: "#{Rails.application.config.x.shopify_url}/auth/shopify/callback",
    setup: lambda { |env|
      strategy = env.fetch('omniauth.strategy')
      strategy.options[:client_options][:auth_scheme] = :request_body
      shop = strategy.request.params['shop'].to_s.strip.downcase
      shop = "#{shop}.myshopify.com" unless shop.include?('.')
      strategy.options[:client_options][:site] = shop.match?(/\A[a-z0-9][a-z0-9-]*\.myshopify\.com\z/) ? "https://#{shop}" : ''
    }
end
OmniAuth.config.allowed_request_methods = [:post]
OmniAuth.config.on_failure = ->(_env) { [401, { 'Content-Type' => 'text/plain' }, ['Shopify authentication failed.']] }
