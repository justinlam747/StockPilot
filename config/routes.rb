# frozen_string_literal: true

Rails.application.routes.draw do
  root 'landing#index'

  post '/connections/shopify', to: 'connections#shopify_connect', as: :shopify_connect
  get '/auth/shopify/callback', to: 'connections#shopify_callback'
  get '/auth/failure', to: 'connections#failure'
  delete '/connections/shopify/:id', to: 'connections#shopify_disconnect', as: :shopify_disconnect

  get '/health', to: 'health#show'

  get '/dashboard', to: 'dashboard#index'
  post '/sync', to: 'dashboard#sync', as: :sync_catalog

  resources :issues, controller: 'alerts', only: [:index]

  get '/settings', to: 'settings#show'
  patch '/settings', to: 'settings#update'

  post '/webhooks/:topic', to: 'webhooks#receive'

  post '/gdpr/customers_data_request', to: 'gdpr#customers_data_request'
  post '/gdpr/customers_redact', to: 'gdpr#customers_redact'
  post '/gdpr/shop_redact', to: 'gdpr#shop_redact'
end
