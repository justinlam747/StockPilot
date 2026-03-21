# frozen_string_literal: true

Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins(
      ENV.fetch('SHOPIFY_APP_URL', 'https://localhost:3000'),
      'https://admin.shopify.com'
    )
    resource '*',
             headers: :any,
             methods: %i[get post put patch delete options head],
             credentials: true
  end
end
