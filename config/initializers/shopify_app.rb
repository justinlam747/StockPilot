ShopifyApp.configure do |config|
  config.application_name = "Inventory Intelligence"
  config.old_secret       = ""
  config.scope            = "read_products,read_inventory,read_orders,read_customers"
  config.embedded_app     = true
  config.after_authenticate_job = { job: "AfterAuthenticateJob", inline: false }
  config.api_version      = "2025-01"
  config.shop_session_repository = "Shop"

  config.api_key  = ENV.fetch("SHOPIFY_API_KEY", "")
  config.secret   = ENV.fetch("SHOPIFY_API_SECRET", "")
  config.host     = ENV.fetch("SHOPIFY_APP_URL", "")

  config.webhooks = [
    { topic: "app/uninstalled",        address: "api/webhooks/app_uninstalled" },
    { topic: "products/update",        address: "api/webhooks/products_update" },
    { topic: "products/delete",        address: "api/webhooks/products_delete" },
    { topic: "customers/data_request", address: "api/webhooks/customers_data_request" },
    { topic: "customers/redact",       address: "api/webhooks/customers_redact" },
    { topic: "shop/redact",            address: "api/webhooks/shop_redact" },
  ]
end
