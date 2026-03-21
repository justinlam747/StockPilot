# frozen_string_literal: true

Rails.application.config.middleware.use OmniAuth::Builder do
  provider :shopify,
           ENV.fetch('SHOPIFY_API_KEY'),
           ENV.fetch('SHOPIFY_API_SECRET'),
           scope: 'read_products,read_inventory,read_orders,read_customers',
           callback_url: "#{ENV.fetch('SHOPIFY_APP_URL')}/auth/shopify/callback",
           setup: proc { |env|
             strategy = env['omniauth.strategy']

             # Always read shop from request params (POST body), not stale session data.
             # The default setup proc checks session first, which can contain stale/empty data
             # and cause invalid_site errors.
             shop = strategy.request.params['shop']

             if shop && !shop.empty?
               shop = shop.strip.downcase
               shop = "#{shop}.myshopify.com" unless shop.include?('.')
               strategy.options[:client_options][:site] = "https://#{shop}"
             else
               strategy.options[:client_options][:site] = ''
             end

             site = strategy.options[:client_options][:site]
             Rails.logger.info "[OmniAuth] Shop param: #{shop.inspect}, Site: #{site}"
           }
end

OmniAuth.config.allowed_request_methods = [:post]

# Skip OmniAuth's CSRF token verification for the request phase.
# OAuth2's `state` parameter already provides CSRF protection for the full flow.
# The omniauth-rails_csrf_protection gem's token verifier is incompatible with
# Rails 7's per-form token masking, causing false InvalidAuthenticityToken errors.
OmniAuth.config.request_validation_phase = nil
