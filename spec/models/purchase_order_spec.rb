# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PurchaseOrder do
  let(:shop) { create(:shop) }

  describe 'associations' do
    subject do
      ActsAsTenant.with_tenant(shop) do
        supplier = create(:supplier, shop: shop)
        create(:purchase_order, shop: shop, supplier: supplier)
      end
    end

    it { is_expected.to belong_to(:supplier) }
    it { is_expected.to belong_to(:source_agent_run).class_name('AgentRun').optional }
    it { is_expected.to belong_to(:source_agent_action).class_name('AgentAction').optional }
    it { is_expected.to have_many(:line_items).class_name('PurchaseOrderLineItem').dependent(:destroy) }
  end

  describe 'validations' do
    subject do
      ActsAsTenant.with_tenant(shop) do
        supplier = create(:supplier, shop: shop)
        create(:purchase_order, shop: shop, supplier: supplier)
      end
    end

    it { is_expected.to validate_presence_of(:status) }
    it { is_expected.to validate_inclusion_of(:status).in_array(%w[draft sent received cancelled]) }
    it { is_expected.to validate_presence_of(:order_date) }

    context 'expected_delivery comparison' do
      it 'is valid when expected_delivery is on or after order_date' do
        ActsAsTenant.with_tenant(shop) do
          supplier = create(:supplier, shop: shop)
          po = build(:purchase_order, shop: shop, supplier: supplier,
                                      order_date: Date.current, expected_delivery: Date.current + 7)
          expect(po).to be_valid
        end
      end

      it 'is valid when expected_delivery equals order_date' do
        ActsAsTenant.with_tenant(shop) do
          supplier = create(:supplier, shop: shop)
          po = build(:purchase_order, shop: shop, supplier: supplier,
                                      order_date: Date.current, expected_delivery: Date.current)
          expect(po).to be_valid
        end
      end

      it 'is invalid when expected_delivery is before order_date' do
        ActsAsTenant.with_tenant(shop) do
          supplier = create(:supplier, shop: shop)
          po = build(:purchase_order, shop: shop, supplier: supplier,
                                      order_date: Date.current, expected_delivery: Date.current - 1)
          expect(po).not_to be_valid
          expect(po.errors[:expected_delivery]).to be_present
        end
      end

      it 'is valid when expected_delivery is nil' do
        ActsAsTenant.with_tenant(shop) do
          supplier = create(:supplier, shop: shop)
          po = build(:purchase_order, shop: shop, supplier: supplier,
                                      order_date: Date.current, expected_delivery: nil)
          expect(po).to be_valid
        end
      end
    end
  end

  describe 'scopes' do
    let!(:draft_po) do
      ActsAsTenant.with_tenant(shop) do
        supplier = create(:supplier, shop: shop)
        create(:purchase_order, shop: shop, supplier: supplier, status: 'draft')
      end
    end

    let!(:sent_po) do
      ActsAsTenant.with_tenant(shop) do
        supplier = create(:supplier, shop: shop)
        create(:purchase_order, shop: shop, supplier: supplier, status: 'sent')
      end
    end

    let!(:received_po) do
      ActsAsTenant.with_tenant(shop) do
        supplier = create(:supplier, shop: shop)
        create(:purchase_order, shop: shop, supplier: supplier, status: 'received')
      end
    end

    describe '.draft' do
      it 'returns only draft purchase orders' do
        ActsAsTenant.with_tenant(shop) do
          expect(described_class.draft).to include(draft_po)
          expect(described_class.draft).not_to include(sent_po, received_po)
        end
      end
    end

    describe '.sent' do
      it 'returns only sent purchase orders' do
        ActsAsTenant.with_tenant(shop) do
          expect(described_class.sent).to include(sent_po)
          expect(described_class.sent).not_to include(draft_po, received_po)
        end
      end
    end

    describe '.received' do
      it 'returns only received purchase orders' do
        ActsAsTenant.with_tenant(shop) do
          expect(described_class.received).to include(received_po)
          expect(described_class.received).not_to include(draft_po, sent_po)
        end
      end
    end
  end

  describe '#set_defaults callback' do
    it 'sets order_date to today when not provided' do
      ActsAsTenant.with_tenant(shop) do
        supplier = create(:supplier, shop: shop)
        po = described_class.create!(shop: shop, supplier: supplier)

        expect(po.order_date).to eq(Date.current)
      end
    end

    it 'sets status to draft when not provided' do
      ActsAsTenant.with_tenant(shop) do
        supplier = create(:supplier, shop: shop)
        po = described_class.create!(shop: shop, supplier: supplier)

        expect(po.status).to eq('draft')
      end
    end

    it 'does not override explicitly set order_date' do
      ActsAsTenant.with_tenant(shop) do
        supplier = create(:supplier, shop: shop)
        custom_date = Date.current - 5.days
        po = described_class.create!(shop: shop, supplier: supplier, order_date: custom_date)

        expect(po.order_date).to eq(custom_date)
      end
    end

    it 'does not override explicitly set status' do
      ActsAsTenant.with_tenant(shop) do
        supplier = create(:supplier, shop: shop)
        po = described_class.create!(shop: shop, supplier: supplier, status: 'sent')

        expect(po.status).to eq('sent')
      end
    end
  end

  describe 'nested attributes' do
    it 'accepts nested attributes for line items' do
      ActsAsTenant.with_tenant(shop) do
        supplier = create(:supplier, shop: shop)
        product = create(:product, shop: shop)
        variant = create(:variant, shop: shop, product: product)

        po = described_class.create!(
          shop: shop,
          supplier: supplier,
          status: 'draft',
          order_date: Date.current,
          expected_delivery: Date.current + 14.days,
          line_items_attributes: [
            { variant: variant, sku: 'SKU-001', qty_ordered: 10, unit_price: 5.00 }
          ]
        )

        expect(po.line_items.count).to eq(1)
        expect(po.line_items.first.sku).to eq('SKU-001')
      end
    end
  end

  describe 'tenant scoping' do
    it 'automatically scopes to the current tenant' do
      po = ActsAsTenant.with_tenant(shop) do
        supplier = create(:supplier, shop: shop)
        create(:purchase_order, shop: shop, supplier: supplier)
      end

      other_shop = create(:shop)
      other_po = ActsAsTenant.with_tenant(other_shop) do
        supplier = create(:supplier, shop: other_shop)
        create(:purchase_order, shop: other_shop, supplier: supplier)
      end

      ActsAsTenant.with_tenant(shop) do
        expect(described_class.all).to include(po)
        expect(described_class.all).not_to include(other_po)
      end
    end
  end
end
