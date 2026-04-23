# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Agents::InventoryMonitor do
  let(:shop) { create(:shop, settings: { 'low_stock_threshold' => 10 }) }
  let(:supplier) { create(:supplier, shop: shop, name: 'Acme Supply') }
  let(:product) { create(:product, shop: shop, title: 'Widget') }
  let(:supplier_variant) do
    create(:variant, shop: shop, product: product, supplier: supplier, sku: 'W-OUT', title: 'Blue')
  end
  let(:supplierless_variant) do
    create(:variant, shop: shop, product: product, sku: 'W-LOW', title: 'Red')
  end
  let(:run) do
    create(
      :agent_run,
      shop: shop,
      goal: 'Focus on urgent stockouts',
      input_payload: { 'correction' => 'Ignore accessories' }
    )
  end
  let(:summary_client) do
    instance_double(Agents::SummaryClient, generate: 'Summary text', provider_name: 'fallback')
  end

  before do
    ActsAsTenant.current_tenant = shop
    create(:inventory_snapshot, shop: shop, variant: supplier_variant, available: 0, on_hand: 0)
    create(:inventory_snapshot, shop: shop, variant: supplierless_variant, available: 3, on_hand: 3)
  end

  it 'records events, proposed actions, and a completed result payload' do
    described_class.new(shop, summary_client: summary_client).execute(run)

    expect(run.reload.status).to eq('completed')
    expect(run.summary).to eq('Summary text')
    expect(run.events.pluck(:event_type)).to include('progress', 'goal', 'correction', 'summary')
    expect(run.actions.pluck(:action_type)).to include('reorder_review', 'supplier_assignment', 'urgent_restock')
    expect(run.result_payload.dig('counts', 'out_of_stock')).to eq(1)
    expect(run.result_payload.dig('counts', 'supplierless')).to eq(1)
  end

  it 'applies correction rules before proposing actions and carries parent context' do
    parent_run = create(:agent_run, shop: shop, summary: 'Previous operator summary')
    corrected_run = create(
      :agent_run,
      shop: shop,
      parent_run: parent_run,
      input_payload: {
        'correction' => 'Ignore supplierless SKUs and focus on out-of-stock items',
        'previous_summary' => parent_run.summary
      }
    )

    described_class.new(shop, summary_client: summary_client).execute(corrected_run)

    expect(corrected_run.actions.pluck(:action_type)).to include('reorder_review', 'urgent_restock')
    expect(corrected_run.actions.pluck(:action_type)).not_to include('supplier_assignment')
    expect(corrected_run.events.find_by(event_type: 'correction_applied').metadata['parent_run_id']).to eq(parent_run.id)
    expect(corrected_run.result_payload['previous_summary']).to eq('Previous operator summary')
    expect(corrected_run.result_payload.dig('counts', 'supplierless')).to eq(0)
  end

  it 'completes cleanly when no SKUs are flagged' do
    healthy_shop = create(:shop, settings: { 'low_stock_threshold' => 10 })
    healthy_summary_client = instance_double(Agents::SummaryClient, generate: 'All clear', provider_name: 'fallback')

    ActsAsTenant.with_tenant(healthy_shop) do
      healthy_product = create(:product, shop: healthy_shop, title: 'Healthy Widget')
      healthy_variant = create(:variant, shop: healthy_shop, product: healthy_product, sku: 'OK-1')
      healthy_run = create(:agent_run, shop: healthy_shop)
      create(:inventory_snapshot, shop: healthy_shop, variant: healthy_variant, available: 50, on_hand: 50)
      described_class.new(healthy_shop, summary_client: healthy_summary_client).execute(healthy_run)

      expect(healthy_run.reload.status).to eq('completed')
      expect(healthy_run.result_payload.dig('counts', 'low_stock')).to eq(0)
      expect(healthy_run.result_payload.dig('counts', 'out_of_stock')).to eq(0)
      expect(healthy_run.actions).to be_empty
    end
  end
end
