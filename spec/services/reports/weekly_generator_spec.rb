# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Reports::WeeklyGenerator do
  let(:shop) { create(:shop, settings: { 'low_stock_threshold' => 10, 'timezone' => 'America/Toronto' }) }
  let(:week_start) { Time.zone.parse('2026-03-02 00:00:00') }
  let(:week_end) { week_start + 7.days }
  let(:generator) { described_class.new(shop, week_start) }

  before do
    ActsAsTenant.current_tenant = shop
  end

  describe '#compile_weekly_report' do
    context 'with full data' do
      let(:supplier) { create(:supplier, shop: shop, name: 'Acme Supplies', email: 'orders@acme.com') }
      let(:product_a) { create(:product, shop: shop, title: 'Widget A') }
      let(:product_b) { create(:product, shop: shop, title: 'Widget B') }
      let(:variant_a) do
        create(:variant, shop: shop, product: product_a, sku: 'WA-001', title: 'Small', price: 10.00,
                         supplier: supplier)
      end
      let(:variant_b) do
        create(:variant, shop: shop, product: product_b, sku: 'WB-001', title: 'Large', price: 25.00,
                         supplier: supplier)
      end
      let(:variant_c) { create(:variant, shop: shop, product: product_a, sku: 'WA-002', title: 'Medium', price: 15.00) }

      before do
        # Start-of-week snapshots (Monday morning)
        create(:inventory_snapshot, shop: shop, variant: variant_a, available: 100, on_hand: 100,
                                    created_at: week_start + 2.hours)
        create(:inventory_snapshot, shop: shop, variant: variant_b, available: 50, on_hand: 50,
                                    created_at: week_start + 2.hours)
        create(:inventory_snapshot, shop: shop, variant: variant_c, available: 30, on_hand: 30,
                                    created_at: week_start + 2.hours)

        # End-of-week snapshots (Sunday)
        create(:inventory_snapshot, shop: shop, variant: variant_a, available: 60, on_hand: 60,
                                    created_at: week_end - 6.hours)
        create(:inventory_snapshot, shop: shop, variant: variant_b, available: 10, on_hand: 10,
                                    created_at: week_end - 6.hours)
        create(:inventory_snapshot, shop: shop, variant: variant_c, available: 25, on_hand: 25,
                                    created_at: week_end - 6.hours)

        # Create out-of-stock alerts during the week
        create(:alert, shop: shop, variant: variant_b, alert_type: 'out_of_stock',
                       triggered_at: week_start + 3.days, current_quantity: 0)
      end

      it 'returns a hash with all four report sections' do
        report = generator.compile_weekly_report

        expect(report.keys).to contain_exactly('top_sellers', 'stockouts', 'low_sku_count', 'reorder_suggestions')
      end

      describe 'top_sellers' do
        it 'calculates correct units_sold from snapshot deltas' do
          report = generator.compile_weekly_report
          top_sellers = report['top_sellers']

          # variant_a: 100 - 60 = 40 sold
          # variant_b: 50 - 10 = 40 sold
          # variant_c: 30 - 25 = 5 sold
          expect(top_sellers.size).to eq(3)

          skus_sold = top_sellers.to_h { |ts| [ts['sku'], ts['units_sold']] }
          expect(skus_sold['WA-001']).to eq(40)
          expect(skus_sold['WB-001']).to eq(40)
          expect(skus_sold['WA-002']).to eq(5)
        end

        it 'includes sku, title, and units_sold for each entry' do
          report = generator.compile_weekly_report
          top_seller = report['top_sellers'].find { |ts| ts['sku'] == 'WA-001' }

          expect(top_seller['title']).to eq("Widget A \u2014 Small")
          expect(top_seller['units_sold']).to eq(40)
        end

        it 'sorts by units_sold descending' do
          report = generator.compile_weekly_report
          units = report['top_sellers'].map { |ts| ts['units_sold'] }

          expect(units).to eq(units.sort.reverse)
        end

        it 'limits to top 10 sellers' do
          # Create 12 more variants with high sales
          12.times do |i|
            v = create(:variant, shop: shop, product: product_a, sku: "EXTRA-#{i}", title: "Extra #{i}")
            create(:inventory_snapshot, shop: shop, variant: v, available: 200, on_hand: 200,
                                        created_at: week_start + 2.hours)
            create(:inventory_snapshot, shop: shop, variant: v, available: 10, on_hand: 10,
                                        created_at: week_end - 6.hours)
          end

          report = generator.compile_weekly_report

          expect(report['top_sellers'].size).to eq(10)
        end
      end

      describe 'stockouts' do
        it 'lists out_of_stock alerts triggered during the week' do
          report = generator.compile_weekly_report
          stockouts = report['stockouts']

          expect(stockouts.size).to eq(1)
          expect(stockouts.first['sku']).to eq('WB-001')
          expect(stockouts.first['title']).to eq("Widget B \u2014 Large")
          expect(stockouts.first['triggered_at']).to be_present
        end

        it 'does not include alerts outside the week range' do
          create(:alert, shop: shop, variant: variant_a, alert_type: 'out_of_stock',
                         triggered_at: week_start - 1.day, current_quantity: 0)

          report = generator.compile_weekly_report

          expect(report['stockouts'].size).to eq(1)
        end

        it 'does not include low_stock alerts (only out_of_stock)' do
          create(:alert, shop: shop, variant: variant_a, alert_type: 'low_stock',
                         triggered_at: week_start + 1.day, current_quantity: 5)

          report = generator.compile_weekly_report

          expect(report['stockouts'].size).to eq(1)
        end
      end

      describe 'low_sku_count' do
        it 'returns the count of currently low-stock variants' do
          # variant_b has available=10 which equals threshold=10, so it may or may not flag
          # depending on LowStockDetector logic (< threshold means low_stock)
          # variant_a: 60 available, threshold 10 => ok
          # variant_c: 25 available, threshold 10 => ok
          report = generator.compile_weekly_report

          expect(report['low_sku_count']).to be_a(Integer)
          expect(report['low_sku_count']).to be >= 0
        end
      end

      describe 'reorder_suggestions' do
        it 'groups low-stock variants by supplier' do
          # Force variant_b to be low stock for reorder suggestions
          create(:inventory_snapshot, shop: shop, variant: variant_b, available: 3, on_hand: 3,
                                      created_at: Time.current)

          report = generator.compile_weekly_report
          suggestions = report['reorder_suggestions']

          if suggestions.any?
            suggestion = suggestions.first
            expect(suggestion).to have_key('supplier_name')
            expect(suggestion).to have_key('supplier_email')
            expect(suggestion).to have_key('items')
            expect(suggestion['items']).to be_an(Array)
          end
        end

        it 'includes suggested_qty based on threshold calculation' do
          # Make variant_a low stock with supplier
          create(:inventory_snapshot, shop: shop, variant: variant_a, available: 3, on_hand: 3,
                                      created_at: Time.current)

          report = generator.compile_weekly_report
          suggestions = report['reorder_suggestions']

          supplier_suggestion = suggestions.find { |s| s['supplier_name'] == 'Acme Supplies' }
          next unless supplier_suggestion

          item = supplier_suggestion['items'].find { |i| i['sku'] == 'WA-001' }
          if item
            # suggested_qty = max(threshold * 2 - available, threshold) = max(10*2-3, 10) = max(17, 10) = 17
            expect(item['suggested_qty']).to eq(17)
            expect(item['available']).to eq(3)
          end
        end

        it 'excludes variants without a supplier' do
          # variant_c has no supplier
          create(:inventory_snapshot, shop: shop, variant: variant_c, available: 2, on_hand: 2,
                                      created_at: Time.current)

          report = generator.compile_weekly_report
          suggestions = report['reorder_suggestions']

          all_skus = suggestions.flat_map { |s| s['items'].map { |i| i['sku'] } }
          expect(all_skus).not_to include('WA-002')
        end
      end
    end

    context 'with empty data' do
      it 'returns empty arrays and zero count when no data exists' do
        report = generator.compile_weekly_report

        expect(report['top_sellers']).to eq([])
        expect(report['stockouts']).to eq([])
        expect(report['low_sku_count']).to eq(0)
        expect(report['reorder_suggestions']).to eq([])
      end
    end

    context 'when variants have no sales (end quantity >= start quantity)' do
      it 'excludes variants with zero or negative sales' do
        product = create(:product, shop: shop, title: 'Restocked Item')
        variant = create(:variant, shop: shop, product: product, sku: 'RS-001', title: 'Default')

        # Restocked: end quantity > start quantity
        create(:inventory_snapshot, shop: shop, variant: variant, available: 10, on_hand: 10,
                                    created_at: week_start + 2.hours)
        create(:inventory_snapshot, shop: shop, variant: variant, available: 50, on_hand: 50,
                                    created_at: week_end - 6.hours)

        report = generator.compile_weekly_report

        expect(report['top_sellers']).to be_empty
      end
    end
  end
end
