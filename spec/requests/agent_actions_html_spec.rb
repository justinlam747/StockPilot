# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Agent actions' do
  let(:shop) { create(:shop) }
  let(:supplier) { create(:supplier, shop: shop) }
  let(:product) { create(:product, shop: shop) }
  let(:variant) { create(:variant, shop: shop, product: product, supplier: supplier, sku: 'SKU-1') }
  let(:run) { create(:agent_run, shop: shop, status: 'completed') }

  before do
    login_as(shop)
    ActsAsTenant.current_tenant = shop
  end

  describe 'PATCH /agent_actions/:id/accept' do
    it 'applies a reorder action and redirects to the agent run' do
      action = create(
        :agent_action,
        agent_run: run,
        action_type: 'purchase_order_draft',
        payload: {
          'supplier_id' => supplier.id,
          'items' => [{ 'variant_id' => variant.id, 'recommended_quantity' => 12, 'sku' => variant.sku }]
        }
      )

      expect do
        patch accept_agent_action_path(action)
      end.to change(PurchaseOrder, :count).by(1)

      expect(response).to redirect_to(agent_path(run))
      expect(action.reload.status).to eq('applied')
      expect(flash[:notice]).to include('Draft purchase order')
    end
  end

  describe 'PATCH /agent_actions/:id/reject' do
    it 'rejects a proposed recommendation without side effects' do
      action = create(:agent_action, agent_run: run, action_type: 'supplier_assignment')

      expect do
        patch reject_agent_action_path(action), params: { feedback_note: 'Not needed' }
      end.not_to change(PurchaseOrder, :count)

      expect(response).to redirect_to(agent_path(run))
      expect(action.reload.status).to eq('rejected')
      expect(action.feedback_note).to eq('Not needed')
    end
  end

  describe 'PATCH /agent_actions/:id/edit_recommendation' do
    let(:other_supplier) { create(:supplier, shop: shop, name: 'Other Supplier') }
    let(:action) do
      create(
        :agent_action,
        agent_run: run,
        action_type: 'reorder_recommendation',
        payload: {
          'variant_id' => variant.id,
          'supplier_id' => supplier.id,
          'recommended_quantity' => 10,
          'items' => [{ 'variant_id' => variant.id, 'recommended_quantity' => 10 }]
        }
      )
    end

    it 'edits quantity and supplier in the action payload', :aggregate_failures do
      patch edit_recommendation_agent_action_path(action),
            params: {
              recommended_quantity: 25,
              supplier_id: other_supplier.id,
              feedback_note: 'Order more this time'
            }

      action.reload
      expect(response).to redirect_to(agent_path(run))
      expect(action.status).to eq('edited')
      expect(action.payload['recommended_quantity']).to eq(25)
      expect(action.payload['supplier_id']).to eq(other_supplier.id)
      expect(action.payload.dig('merchant_overrides', 'recommended_quantity')).to eq(25)
    end
  end

  it 'does not allow access to actions owned by another shop' do
    other_shop = create(:shop)
    foreign_action = ActsAsTenant.with_tenant(other_shop) do
      foreign_run = create(:agent_run, shop: other_shop)
      create(:agent_action, agent_run: foreign_run)
    end

    expect do
      patch accept_agent_action_path(foreign_action)
    end.not_to change(PurchaseOrder, :count)

    expect(response).to have_http_status(:not_found)
  end
end
