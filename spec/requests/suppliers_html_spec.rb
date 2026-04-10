# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Suppliers' do
  let(:shop) { create(:shop) }

  before { login_as(shop) }

  describe 'GET /suppliers' do
    it 'returns success' do
      get '/suppliers'
      expect(response).to have_http_status(:ok)
    end
  end

  describe 'POST /suppliers' do
    let(:valid_params) { { supplier: { name: 'Acme Co', email: 'acme@example.com', lead_time_days: 7 } } }

    it 'creates a supplier' do
      expect { post '/suppliers', params: valid_params }.to change(Supplier, :count).by(1)
    end

    it 'creates an audit log' do
      expect do
        post '/suppliers', params: valid_params
      end.to change(AuditLog.where(action: 'supplier_created'), :count).by(1)
    end
  end

  describe 'DELETE /suppliers/:id' do
    let!(:supplier) { create(:supplier, shop: shop) }

    it 'deletes the supplier' do
      expect { delete "/suppliers/#{supplier.id}" }.to change(Supplier, :count).by(-1)
    end

    it 'creates an audit log' do
      expect { delete "/suppliers/#{supplier.id}" }.to change(AuditLog.where(action: 'supplier_deleted'), :count).by(1)
    end
  end

  describe 'PATCH /suppliers/:id' do
    let!(:supplier) { create(:supplier, shop: shop, star_rating: 0) }

    it 'updates star rating' do
      patch "/suppliers/#{supplier.id}", params: { supplier: { star_rating: 4 } }
      expect(supplier.reload.star_rating).to eq(4)
    end
  end
end
