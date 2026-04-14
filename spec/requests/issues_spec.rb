# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Issues', type: :request do
  describe 'GET /issues' do
    it 'filters catalog issues by severity' do
      shop = create(:shop)
      allow_any_instance_of(ApplicationController).to receive(:current_shop).and_return(shop)

      product = create(:product, shop: shop, title: 'Issue Product', vendor: nil, product_type: 'Type', image_url: 'https://img.test/1.png')
      create(:variant, shop: shop, product: product, sku: 'SKU-1', price: 0)

      get '/issues', params: { severity: 'critical' }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Missing or zero price')
      expect(response.body).not_to include('Blank vendor')
    end
  end
end
