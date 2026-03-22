# frozen_string_literal: true

Rails.application.routes.draw do
  root 'landing#index'

  # Clerk handles sign-in/sign-up via JS SDK — no server routes needed for login

  # Onboarding wizard
  get '/onboarding', to: 'onboarding#index', as: :onboarding
  get '/onboarding/step/:step', to: 'onboarding#show', as: :onboarding_step
  post '/onboarding/step/:step', to: 'onboarding#update'

  # Shopify store connection (OAuth)
  post '/connections/shopify', to: 'connections#shopify_connect', as: :shopify_connect
  get '/auth/shopify/callback', to: 'connections#shopify_callback'
  get '/auth/failure', to: 'connections#failure'
  delete '/connections/shopify/:id', to: 'connections#shopify_disconnect', as: :shopify_disconnect

  # Shop switching
  patch '/shops/:id/switch', to: 'shops#switch', as: :switch_shop

  # User account
  get '/account', to: 'account#show'
  delete '/logout', to: 'account#destroy'

  # Health check (unauthenticated)
  get '/health', to: 'health#show'

  # Vision / Blog (public)
  get '/vision', to: 'vision#index'

  # App
  get '/dashboard', to: 'dashboard#index'
  post '/dashboard/toggle_demo', to: 'dashboard#toggle_demo'
  post '/agents/run', to: 'dashboard#run_agent'

  resources :inventory, only: %i[index show]
  resources :suppliers, except: %i[new edit]
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

  # Settings
  get '/settings', to: 'settings#show'
  patch '/settings', to: 'settings#update'

  # Clerk webhooks (must be before Shopify catch-all to avoid route conflict)
  post '/webhooks/clerk', to: 'webhooks/clerk#receive'

  # Shopify webhooks (catch-all — must come after specific webhook routes)
  post '/webhooks/:topic', to: 'webhooks#receive'

  # GDPR (required by Shopify)
  post '/gdpr/customers_data_request', to: 'gdpr#customers_data_request'
  post '/gdpr/customers_redact', to: 'gdpr#customers_redact'
  post '/gdpr/shop_redact', to: 'gdpr#shop_redact'

  # Dev-only auto-login (bypasses auth for local viewing)
  get '/dev/login', to: 'account#dev_login' if Rails.env.development?
end
