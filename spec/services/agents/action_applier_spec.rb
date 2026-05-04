# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Agents::ActionApplier do
  let(:shop) { create(:shop) }
  let(:supplier) { create(:supplier, shop: shop, lead_time_days: 7) }
  let(:product) { create(:product, shop: shop) }
  let(:variant) { create(:variant, shop: shop, product: product, supplier: supplier, sku: 'SKU-1', price: 12.50) }
  let(:run) { create(:agent_run, shop: shop, status: 'completed') }

  before do
    ActsAsTenant.current_tenant = shop
  end

  it 'creates a draft purchase order from an accepted reorder recommendation', :aggregate_failures do
    action = create(
      :agent_action,
      agent_run: run,
      action_type: 'reorder_recommendation',
      payload: {
        'supplier_id' => supplier.id,
        'items' => [
          {
            'variant_id' => variant.id,
            'sku' => variant.sku,
            'variant_title' => variant.title,
            'recommended_quantity' => 20,
            'unit_price' => '12.5'
          }
        ]
      }
    )

    expect do
      @purchase_order = described_class.call(action: action, actor: shop.shop_domain)
    end.to change(PurchaseOrder, :count).by(1)
                                        .and change(PurchaseOrderLineItem, :count).by(1)

    expect(@purchase_order.status).to eq('draft')
    expect(@purchase_order.source).to eq('agent_action')
    expect(@purchase_order.source_agent_run).to eq(run)
    expect(@purchase_order.line_items.first.qty_ordered).to eq(20)
    expect(action.reload.status).to eq('applied')
    expect(action.payload['applied_purchase_order_id']).to eq(@purchase_order.id)
  end

  it 'updates a variant threshold from an accepted threshold recommendation' do
    action = create(
      :agent_action,
      agent_run: run,
      action_type: 'threshold_adjustment',
      payload: {
        'variant_id' => variant.id,
        'recommended_threshold' => 25
      }
    )

    result = described_class.call(action: action, actor: shop.shop_domain)

    expect(result).to eq(variant)
    expect(variant.reload.low_stock_threshold).to eq(25)
    expect(action.reload.status).to eq('applied')
    expect(action.resolution_note).to include('Updated threshold')
  end

  it 'marks manual supplier assignment actions accepted without workflow side effects' do
    action = create(
      :agent_action,
      agent_run: run,
      action_type: 'supplier_assignment',
      payload: { 'variant_id' => variant.id, 'sku' => variant.sku }
    )

    expect do
      result = described_class.call(action: action, actor: shop.shop_domain)
      expect(result).to eq(action)
    end.not_to change(PurchaseOrder, :count)

    expect(action.reload.status).to eq('accepted')
    expect(action.resolution_note).to eq('Accepted for manual follow-up.')
  end

  it 'fails with a structured error when supplier is missing' do
    action = create(
      :agent_action,
      agent_run: run,
      action_type: 'purchase_order_draft',
      payload: {
        'supplier_id' => -1,
        'items' => [{ 'variant_id' => variant.id, 'recommended_quantity' => 10 }]
      }
    )

    expect do
      described_class.call(action: action, actor: shop.shop_domain)
    end.to raise_error(Agents::ActionApplier::ApplicationFailure) { |error|
      expect(error.error.code).to eq('SUPPLIER_NOT_FOUND')
    }

    expect(action.reload.status).to eq('failed')
    expect(action.resolution_note).to include('SUPPLIER_NOT_FOUND')
  end
end
