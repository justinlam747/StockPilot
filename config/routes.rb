Rails.application.routes.draw do
  root "landing#index"

  # Auth
  get "/auth/shopify/callback", to: "auth#callback"
  get "/auth/failure", to: "auth#failure"
  delete "/logout", to: "auth#destroy"

  # Dev login (development only)
  if Rails.env.development?
    get "/dev_login", to: "auth#dev_login"
  end

  # Health check (unauthenticated)
  get "/health", to: "health#show"

  # App
  get "/dashboard", to: "dashboard#index"
  post "/agents/run", to: "dashboard#run_agent"

  resources :inventory, only: [:index, :show]
  resources :suppliers, except: [:new, :edit]
  resources :purchase_orders do
    member do
      patch :mark_sent
      patch :mark_received
    end
    collection do
      post :generate_draft
    end
  end
  resources :alerts, only: [:index] do
    member do
      patch :dismiss
    end
  end

  # Shopify webhooks
  post "/webhooks/:topic", to: "webhooks#receive"

  # GDPR (required by Shopify)
  post "/gdpr/customers_data_request", to: "gdpr#customers_data_request"
  post "/gdpr/customers_redact", to: "gdpr#customers_redact"
  post "/gdpr/shop_redact", to: "gdpr#shop_redact"
end
