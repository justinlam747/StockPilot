# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Dashboard', type: :request do
  describe 'GET /dashboard' do
    it 'shows the connect state when no shop is active' do
      get '/dashboard'

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Connect a Shopify store')
    end

    it 'uses affected products, not raw issue count, for coverage' do
      shop = create(:shop)
      allow_any_instance_of(ApplicationController).to receive(:current_shop).and_return(shop)

      create(:product, shop: shop, title: 'Clean Product', vendor: 'Vendor', product_type: 'Type', image_url: 'https://img.test/1.png')
      flagged_product = create(:product, shop: shop, title: 'Bad', vendor: nil, product_type: nil, image_url: nil)
      create(:variant, shop: shop, product: flagged_product, sku: nil, price: 0)

      get '/dashboard'

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('50%')
    end
  end
end
