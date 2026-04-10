# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Dashboard' do
  let(:shop) { create(:shop) }

  before { login_as(shop) }

  describe 'GET /dashboard' do
    it 'returns success' do
      get '/dashboard'
      expect(response).to have_http_status(:ok)
    end

    it 'shows KPI cards' do
      get '/dashboard'
      expect(response.body).to include('Total Products')
      expect(response.body).to include('Low Stock')
    end
  end
end
