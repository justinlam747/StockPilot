# frozen_string_literal: true

Rails.application.routes.draw do
  root 'landing#index'

  # Shopify store connection (OAuth)
  get '/auth/shopify/callback', to: 'connections#shopify_callback'
  get '/auth/failure', to: 'connections#failure'

  # Health check (unauthenticated)
  get '/health', to: 'health#show'

  # App
  get '/dashboard', to: 'dashboard#index'
  resources :agents, only: %i[index show]
  post '/agents/run', to: 'agents#run', as: :run_agents
  post '/agents/:id/corrections', to: 'agents#corrections', as: :agent_corrections

  resources :inventory, only: %i[index show]
  resources :suppliers, except: %i[new edit]
  resources :purchase_orders do
    member do
      patch :mark_sent
      patch :mark_received
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

  # Shopify webhooks
  post '/webhooks/:topic', to: 'webhooks#receive'

  # GDPR (required by Shopify)
  post '/gdpr/customers_data_request', to: 'gdpr#customers_data_request'
  post '/gdpr/customers_redact', to: 'gdpr#customers_redact'
  post '/gdpr/shop_redact', to: 'gdpr#shop_redact'
end
