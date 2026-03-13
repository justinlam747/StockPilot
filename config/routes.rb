Rails.application.routes.draw do
  # shopify_app gem mounts OAuth + session token routes
  mount ShopifyApp::Engine, at: "/"

  # Health check (unauthenticated)
  get "/health", to: "health#show"

  # Shopify webhook receivers (HMAC-verified)
  post "/api/webhooks/:topic", to: "webhooks#receive",
       constraints: { topic: /[a-z_]+/ }

  # GDPR mandatory endpoints
  post "/api/webhooks/customers_data_request", to: "gdpr#customers_data_request"
  post "/api/webhooks/customers_redact",       to: "gdpr#customers_redact"
  post "/api/webhooks/shop_redact",            to: "gdpr#shop_redact"

  # Authenticated API endpoints (session token JWT verified)
  namespace :api do
    namespace :v1 do
      resource  :shop,        only: [:show, :update]
      resource  :settings,    only: [:show, :update]

      resources :products,    only: [:index, :show]
      resources :variants,    only: [:index, :show, :update]
      post "/inventory/sync", to: "inventory#sync"

      resources :alerts,      only: [:index, :update]

      resources :reports,     only: [:index, :show]
      post "/reports/generate", to: "reports#generate"

      resources :suppliers
      resources :purchase_orders do
        member do
          post :send_email
        end
        collection do
          post :generate_draft
        end
      end

      resources :webhook_endpoints

      # V2
      get  "/ai/insights",     to: "ai#insights"
      get  "/ai/agent_status",  to: "ai#agent_status"
      post "/ai/run_agent",     to: "ai#run_agent"
      resources :customers, only: [:index, :show]
    end
  end
end
