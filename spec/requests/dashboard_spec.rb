# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Dashboard', type: :request do
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

  describe 'POST /agents/run' do
    it 'runs the agent pipeline and redirects' do
      allow_any_instance_of(Inventory::LowStockDetector).to receive(:detect).and_return([])
      post '/agents/run'
      expect(response).to have_http_status(:ok).or have_http_status(:redirect)
    end

    it 'creates an audit log' do
      allow_any_instance_of(Inventory::LowStockDetector).to receive(:detect).and_return([])
      expect { post '/agents/run' }.to change(AuditLog.where(action: 'agent_run'), :count).by(1)
    end
  end
end
