# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Agents::SupplierEmailDraft do
  let(:shop) { create(:shop, settings: { 'alert_email' => 'ops@merchant.example' }) }
  let(:supplier) { create(:supplier, shop: shop, name: 'TextileCo', email: 'orders@textileco.example', lead_time_days: 7) }
  let(:product) { create(:product, shop: shop, title: 'Cotton Tee') }
  let(:variant) { create(:variant, shop: shop, product: product, supplier: supplier, sku: 'SKU-1', title: 'Medium / Black', price: 9.50) }
  let(:purchase_order) do
    po = create(:purchase_order, shop: shop, supplier: supplier, expected_delivery: Date.current + 7)
    po.line_items.create!(variant: variant, sku: variant.sku, title: variant.title, qty_ordered: 30, unit_price: variant.price)
    po
  end

  before { ActsAsTenant.current_tenant = shop }

  it 'returns a draft addressed to the supplier email and shop alert email' do
    draft = described_class.call(purchase_order)

    expect(draft.to).to eq('orders@textileco.example')
    expect(draft.from).to eq('ops@merchant.example')
  end

  it 'includes PO id and shop domain in the subject' do
    draft = described_class.call(purchase_order)

    expect(draft.subject).to include("##{purchase_order.id}")
    expect(draft.subject).to include(shop.shop_domain)
  end

  it 'lists every line item with sku and quantity' do
    draft = described_class.call(purchase_order)

    expect(draft.body).to include('SKU-1')
    expect(draft.body).to include('Medium / Black')
    expect(draft.body).to include('qty 30')
  end

  it 'includes the requested delivery date when expected_delivery is set' do
    draft = described_class.call(purchase_order)

    expect(draft.body).to include('Requested delivery by')
    expect(draft.body).to include(purchase_order.expected_delivery.strftime('%b %d, %Y'))
  end

  it 'omits delivery line when expected_delivery is missing' do
    purchase_order.update!(expected_delivery: nil)
    draft = described_class.call(purchase_order)

    expect(draft.body).not_to include('Requested delivery by')
    expect(draft.body).to include(purchase_order.order_date.strftime('%b %d, %Y'))
  end

  it 'greets the supplier contact name when present, supplier name otherwise' do
    supplier.update!(contact_name: 'Aisha')
    draft = described_class.call(purchase_order)
    expect(draft.body).to start_with('Hi Aisha,')

    supplier.update!(contact_name: nil)
    draft = described_class.call(purchase_order)
    expect(draft.body).to start_with('Hi TextileCo,')
  end
end
