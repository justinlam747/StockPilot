Rails.application.config.middleware.use OmniAuth::Builder do
  provider :shopify,
    ENV.fetch("SHOPIFY_API_KEY"),
    ENV.fetch("SHOPIFY_API_SECRET"),
    scope: "read_products,read_inventory,read_orders"
end

OmniAuth.config.allowed_request_methods = [:post]
