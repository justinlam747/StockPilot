# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Demo Mode' do
  let(:shop) { create(:shop) }

  before(:all) do
    ActsAsTenant.without_tenant { Demo::Seeder.new.seed! }
  end

  after(:all) do
    ActsAsTenant.without_tenant do
      demo_shop = Shop.find_by(shop_domain: 'demo.myshopify.com')
      Demo::Seeder.new.purge_shop_data!(demo_shop) if demo_shop
      demo_shop&.delete
      User.find_by(clerk_user_id: 'demo_user')&.delete
    end
  end

  before { login_as(shop) }

  describe 'POST /dashboard/toggle_demo' do
    it 'enables demo mode and redirects to dashboard' do
      post '/dashboard/toggle_demo'
      expect(response).to redirect_to('/dashboard')
      follow_redirect!
      expect(response.body).to include('Demo Mode').or include('demo')
    end

    it 'disables demo mode on second toggle' do
      post '/dashboard/toggle_demo'
      post '/dashboard/toggle_demo'
      expect(response).to redirect_to('/dashboard')
    end

    it 'returns alert when demo shop does not exist' do
      allow(Shop).to receive(:find_by).and_call_original
      allow(Shop).to receive(:find_by).with(shop_domain: 'demo.myshopify.com').and_return(nil)

      post '/dashboard/toggle_demo'
      expect(response).to redirect_to('/dashboard')
      follow_redirect!
      expect(response.body).to include('Demo data not seeded')
    end
  end

  describe 'demo mode read-only enforcement' do
    before { post '/dashboard/toggle_demo' }

    it 'blocks write actions with redirect' do
      post '/suppliers', params: { supplier: { name: 'Hacker Corp', email: 'x@x.com' } }
      expect(response).to redirect_to('/dashboard')
    end

    it 'allows GET requests' do
      get '/dashboard'
      expect(response).to have_http_status(:ok)
    end

    it 'allows toggle_demo POST to exit demo mode' do
      post '/dashboard/toggle_demo'
      expect(response).to redirect_to('/dashboard')
    end
  end

  describe 'full demo flow integration' do
    it 'enables demo mode, views all major pages, then disables' do
      post '/dashboard/toggle_demo'
      expect(response).to redirect_to('/dashboard')

      get '/dashboard'
      expect(response).to have_http_status(:ok)

      get '/inventory'
      expect(response).to have_http_status(:ok)

      get '/suppliers'
      expect(response).to have_http_status(:ok)

      get '/alerts'
      expect(response).to have_http_status(:ok)

      get '/purchase_orders'
      expect(response).to have_http_status(:ok)

      post '/dashboard/toggle_demo'
      follow_redirect!
      expect(response).to have_http_status(:ok)
    end
  end
end
