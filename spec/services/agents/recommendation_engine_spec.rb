# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Agents::RecommendationEngine do
  let(:shop) { create(:shop, settings: { 'low_stock_threshold' => 10 }) }
  let(:supplier) { create(:supplier, shop: shop, name: 'Acme Supply', lead_time_days: 14) }
  let(:product) { create(:product, shop: shop, title: 'Cotton Tee') }

  before do
    ActsAsTenant.current_tenant = shop
  end

  it 'generates reorder and purchase order draft recommendations for supplier-backed flagged variants',
     :aggregate_failures do
    variant = create(:variant, shop: shop, product: product, supplier: supplier, sku: 'TEE-BLK')
    create(:inventory_snapshot, shop: shop, variant: variant, available: 4, on_hand: 4)

    result = described_class.call(shop: shop)

    expect(result.counts['low_stock']).to eq(1)
    expect(result.recommendations.pluck(:action_type)).to include('reorder_recommendation', 'purchase_order_draft')
    reorder = result.recommendations.find { |rec| rec[:action_type] == 'reorder_recommendation' }
    expect(reorder[:payload]['variant_id']).to eq(variant.id)
    expect(reorder[:payload]['supplier_id']).to eq(supplier.id)
    expect(reorder[:payload]['recommended_quantity']).to eq(16)
    expect(reorder[:details]).to include('threshold of 10')
  end

  it 'generates supplier assignment guidance for supplierless variants' do
    variant = create(:variant, shop: shop, product: product, sku: 'TEE-RED')
    create(:inventory_snapshot, shop: shop, variant: variant, available: 0, on_hand: 0)

    result = described_class.call(shop: shop)

    expect(result.counts['supplierless']).to eq(1)
    expect(result.recommendations.pluck(:action_type)).to include('supplier_assignment')
    expect(result.recommendations.pluck(:action_type)).not_to include('purchase_order_draft')
  end

  it 'respects minimum order quantity and ignored SKU preferences' do
    shop.update_agent_preferences!(
      'min_order_qty' => 50,
      'ignored_skus' => ['IGNORED']
    )
    included = create(:variant, shop: shop, product: product, supplier: supplier, sku: 'INCLUDED')
    ignored = create(:variant, shop: shop, product: product, supplier: supplier, sku: 'IGNORED')
    create(:inventory_snapshot, shop: shop, variant: included, available: 3, on_hand: 3)
    create(:inventory_snapshot, shop: shop, variant: ignored, available: 3, on_hand: 3)

    result = described_class.call(shop: shop)
    reorder = result.recommendations.find { |rec| rec[:action_type] == 'reorder_recommendation' }

    expect(result.flagged.map { |row| row[:variant].sku }).to contain_exactly('INCLUDED')
    expect(reorder[:payload]['recommended_quantity']).to eq(50)
  end

  it 'uses preferred supplier preferences when configured' do
    preferred = create(:supplier, shop: shop, name: 'Preferred Supply')
    variant = create(:variant, shop: shop, product: product, supplier: supplier, sku: 'TEE-GRN')
    shop.update_agent_preferences!('preferred_suppliers' => { variant.id.to_s => preferred.id })
    create(:inventory_snapshot, shop: shop, variant: variant, available: 2, on_hand: 2)

    result = described_class.call(shop: shop)
    reorder = result.recommendations.find { |rec| rec[:action_type] == 'reorder_recommendation' }

    expect(reorder[:payload]['supplier_id']).to eq(preferred.id)
    expect(reorder[:payload]['supplier_name']).to eq('Preferred Supply')
  end

  it 'recommends threshold adjustments for repeatedly alerted variants' do
    variant = create(:variant, shop: shop, product: product, supplier: supplier, sku: 'TEE-WHT')
    create(:inventory_snapshot, shop: shop, variant: variant, available: 1, on_hand: 1)
    3.times { create(:alert, shop: shop, variant: variant, triggered_at: 5.days.ago) }

    result = described_class.call(shop: shop)
    threshold_action = result.recommendations.find { |rec| rec[:action_type] == 'threshold_adjustment' }

    expect(threshold_action).to be_present
    expect(threshold_action[:payload]['current_threshold']).to eq(10)
    expect(threshold_action[:payload]['recommended_threshold']).to be > 10
  end

  it 'applies correction text before building recommendations' do
    stocked = create(:variant, shop: shop, product: product, supplier: supplier, sku: 'OUT')
    supplierless = create(:variant, shop: shop, product: product, sku: 'LOW')
    create(:inventory_snapshot, shop: shop, variant: stocked, available: 0, on_hand: 0)
    create(:inventory_snapshot, shop: shop, variant: supplierless, available: 2, on_hand: 2)

    result = described_class.call(
      shop: shop,
      correction: 'Ignore supplierless SKUs and focus on out-of-stock items'
    )

    expect(result.correction_rules).to include('ignore_supplierless', 'only_out_of_stock')
    expect(result.flagged.map { |row| row[:variant].sku }).to contain_exactly('OUT')
  end
end
