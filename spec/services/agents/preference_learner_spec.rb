# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Agents::PreferenceLearner do
  let(:shop) { create(:shop) }
  let(:supplier) { create(:supplier, shop: shop) }
  let(:product) { create(:product, shop: shop) }
  let(:variant) { create(:variant, shop: shop, product: product, supplier: supplier) }
  let(:run) { create(:agent_run, shop: shop) }

  before do
    ActsAsTenant.current_tenant = shop
  end

  it 'learns preferred supplier mappings from edited action payloads' do
    action = create(
      :agent_action,
      agent_run: run,
      action_type: 'reorder_recommendation',
      payload: {
        'variant_id' => variant.id,
        'supplier_id' => supplier.id,
        'merchant_overrides' => { 'supplier_id' => supplier.id }
      }
    )

    described_class.call(action: action, outcome: 'edited')

    expect(shop.reload.agent_preferences.dig('preferred_suppliers', variant.id.to_s)).to eq(supplier.id)
  end

  it 'adjusts reorder window when merchant edits quantity upward' do
    action = create(
      :agent_action,
      agent_run: run,
      action_type: 'reorder_recommendation',
      payload: {
        'variant_id' => variant.id,
        'supplier_id' => supplier.id,
        'recommended_quantity' => 10,
        'merchant_overrides' => {
          'original_recommended_quantity' => 10,
          'recommended_quantity' => 20
        }
      }
    )

    described_class.call(action: action, outcome: 'edited')

    expect(shop.reload.agent_preferences['default_reorder_days']).to eq(35)
  end
end
