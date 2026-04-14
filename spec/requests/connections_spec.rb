# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Connections', type: :request do
  describe 'POST /connections/shopify' do
    it 'rejects a blank shop domain' do
      post '/connections/shopify', params: { shop_domain: '' }

      expect(response).to redirect_to('/settings')
      expect(flash[:alert]).to eq('Please enter your store URL')
    end

    it 'normalizes bare shop names to myshopify domains' do
      post '/connections/shopify', params: { shop_domain: 'catalog-audit-demo' }

      expect(response).to redirect_to('/auth/shopify?shop=catalog-audit-demo.myshopify.com')
    end
  end
end
