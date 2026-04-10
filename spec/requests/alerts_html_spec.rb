# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Alerts' do
  let(:shop) { create(:shop) }
  let(:product) { create(:product, shop: shop) }
  let(:variant) { create(:variant, shop: shop, product: product) }

  before { login_as(shop) }

  describe 'GET /alerts' do
    it 'returns success' do
      ActsAsTenant.with_tenant(shop) do
        create(:alert, shop: shop, variant: variant)
      end

      get '/alerts'
      expect(response).to have_http_status(:ok)
    end

    it 'filters by active status' do
      ActsAsTenant.with_tenant(shop) do
        create(:alert, shop: shop, variant: variant, dismissed: false)
        create(:alert, shop: shop, variant: variant, dismissed: true)
      end

      get '/alerts', params: { status: 'active' }
      expect(response).to have_http_status(:ok)
    end
  end

  describe 'PATCH /alerts/:id/dismiss' do
    it 'dismisses the alert' do
      alert = ActsAsTenant.with_tenant(shop) do
        create(:alert, shop: shop, variant: variant)
      end

      patch dismiss_alert_path(alert)
      expect(response).to have_http_status(:ok)
      expect(alert.reload.dismissed).to be true
    end

    it 'creates an audit log' do
      alert = ActsAsTenant.with_tenant(shop) do
        create(:alert, shop: shop, variant: variant)
      end

      expect do
        patch dismiss_alert_path(alert)
      end.to change(AuditLog.where(action: 'alert_dismissed'), :count).by(1)
    end
  end
end
