# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Connections' do
  let(:user) { create(:user, :onboarded) }

  before { sign_in_as(user) }

  describe 'POST /connections/shopify' do
    it 'redirects to Shopify OAuth' do
      post '/connections/shopify', params: { shop_domain: 'test-store' }
      expect(response).to have_http_status(:redirect)
    end

    it 'rejects missing shop_domain' do
      post '/connections/shopify', params: {}
      expect(response).to redirect_to('/settings')
    end
  end

  describe 'DELETE /connections/shopify/:id' do
    let!(:shop) { create(:shop, user: user) }

    before { user.update!(active_shop_id: shop.id) }

    it 'soft-disconnects the shop' do
      delete "/connections/shopify/#{shop.id}"
      expect(shop.reload.uninstalled_at).to be_present
      expect(response).to redirect_to('/settings')
    end

    it 'prevents disconnecting another user shop' do
      other_user = create(:user, :onboarded)
      other_shop = create(:shop, shop_domain: 'other.myshopify.com', user: other_user)
      delete "/connections/shopify/#{other_shop.id}"
      # Should not disconnect — either 404 or redirect without disconnecting
      expect(other_shop.reload.uninstalled_at).to be_nil
    end
  end
end
