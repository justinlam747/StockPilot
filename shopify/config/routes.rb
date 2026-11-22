Rails.application.routes.draw do
  root 'connections#show'
  get '/connect', to: 'connections#show'
  get '/auth/shopify/callback', to: 'connections#callback'
  get '/status', to: 'connections#status'
  get '/inventory', to: 'connections#inventory'
  post '/sync', to: 'connections#sync'
  post '/webhooks/:topic', to: 'webhooks#receive', constraints: {topic: /app_uninstalled|products_update|products_delete/}
  post '/gdpr/:topic', to: 'webhooks#receive', constraints: {topic: /customers_data_request|customers_redact|shop_redact/}
end
