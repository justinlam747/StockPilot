# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Agents::InventoryMonitor do
  let(:shop) { create(:shop, settings: { 'low_stock_threshold' => 10 }) }
  let(:mock_anthropic_client) { instance_double(Anthropic::Client) }
  let(:monitor) { described_class.new(shop) }

  before do
    ActsAsTenant.current_tenant = shop
    allow(Anthropic::Client).to receive(:new).and_return(mock_anthropic_client)
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with('ANTHROPIC_API_KEY').and_return('test-key')
  end

  describe 'constants' do
    it 'defines MAX_TURNS as 10' do
      expect(described_class::MAX_TURNS).to eq(10)
    end

    it 'defines 5 tools' do
      tools = monitor.send(:tools_definition)
      expect(tools.size).to eq(5)
      tool_names = tools.map { |t| t[:name] }
      expect(tool_names).to contain_exactly(
        'check_inventory',
        'get_stock_summary',
        'send_alerts',
        'get_recent_alerts',
        'draft_purchase_order'
      )
    end
  end

  describe '#run' do
    context 'when Claude responds with end_turn immediately' do
      it 'completes in 1 turn with a summary' do
        api_response = {
          'stop_reason' => 'end_turn',
          'content' => [{ 'type' => 'text', 'text' => 'All inventory looks healthy.' }]
        }
        allow(mock_anthropic_client).to receive(:messages).and_return(api_response)

        result = monitor.run

        expect(result[:turns]).to eq(1)
        expect(result[:log]).to be_an(Array)
        expect(result[:log].any? { |l| l.include?('Agent summary') }).to be true
      end
    end

    context 'when Claude makes tool calls then ends' do
      it 'processes tool calls and returns results' do
        tool_use_response = {
          'stop_reason' => 'tool_use',
          'content' => [
            { 'type' => 'text', 'text' => 'Let me check inventory.' },
            { 'type' => 'tool_use', 'id' => 'toolu_123', 'name' => 'check_inventory', 'input' => {} }
          ]
        }

        end_turn_response = {
          'stop_reason' => 'end_turn',
          'content' => [{ 'type' => 'text', 'text' => 'All clear, no issues found.' }]
        }

        allow(mock_anthropic_client).to receive(:messages)
          .and_return(tool_use_response, end_turn_response)

        # Mock LowStockDetector to return empty
        allow_any_instance_of(Inventory::LowStockDetector).to receive(:detect).and_return([])

        result = monitor.run

        expect(result[:turns]).to eq(2)
        expect(mock_anthropic_client).to have_received(:messages).twice
      end
    end

    context 'when Claude makes multiple tool calls in one turn' do
      it 'executes all tool calls and returns results for each' do
        multi_tool_response = {
          'stop_reason' => 'tool_use',
          'content' => [
            { 'type' => 'tool_use', 'id' => 'toolu_1', 'name' => 'check_inventory', 'input' => {} },
            { 'type' => 'tool_use', 'id' => 'toolu_2', 'name' => 'get_recent_alerts', 'input' => {} }
          ]
        }

        end_response = {
          'stop_reason' => 'end_turn',
          'content' => [{ 'type' => 'text', 'text' => 'Done.' }]
        }

        allow(mock_anthropic_client).to receive(:messages)
          .and_return(multi_tool_response, end_response)
        allow_any_instance_of(Inventory::LowStockDetector).to receive(:detect).and_return([])

        result = monitor.run

        expect(result[:turns]).to eq(2)
        # Should have tool call logs for both tools
        tool_call_logs = result[:log].select { |l| l.include?('Tool call:') }
        expect(tool_call_logs.size).to eq(2)
      end
    end

    context 'when MAX_TURNS is reached' do
      it 'stops after MAX_TURNS iterations' do
        always_tool_use = {
          'stop_reason' => 'tool_use',
          'content' => [
            { 'type' => 'tool_use', 'id' => 'toolu_loop', 'name' => 'get_stock_summary', 'input' => {} }
          ]
        }

        allow(mock_anthropic_client).to receive(:messages).and_return(always_tool_use)
        allow_any_instance_of(Inventory::LowStockDetector).to receive(:detect).and_return([])

        result = monitor.run

        expect(result[:turns]).to eq(described_class::MAX_TURNS)
      end
    end

    context 'when Anthropic API raises an error' do
      it 'falls back to direct check and returns fallback: true' do
        allow(mock_anthropic_client).to receive(:messages)
          .and_raise(Anthropic::Error.new('API rate limited'))
        allow_any_instance_of(Inventory::LowStockDetector).to receive(:detect).and_return([])
        allow_any_instance_of(Notifications::AlertSender).to receive(:send_low_stock_alerts)

        result = monitor.run

        expect(result[:fallback]).to be true
        expect(result[:turns]).to eq(0)
        expect(result[:log].any? { |l| l.include?('Anthropic API error') }).to be true
        expect(result[:log].any? { |l| l.include?('Running fallback') }).to be true
      end

      it 'sends alerts for flagged variants in fallback mode' do
        product = create(:product, shop: shop, title: 'Low Item')
        variant = create(:variant, shop: shop, product: product, sku: 'LOW-1')
        create(:inventory_snapshot, shop: shop, variant: variant, available: 3, on_hand: 3)

        allow(mock_anthropic_client).to receive(:messages)
          .and_raise(Anthropic::Error.new('API down'))

        alert_sender = instance_double(Notifications::AlertSender)
        allow(Notifications::AlertSender).to receive(:new).with(shop).and_return(alert_sender)
        allow(alert_sender).to receive(:send_low_stock_alerts)

        monitor.run

        expect(alert_sender).to have_received(:send_low_stock_alerts)
          .with(array_including(hash_including(status: :low_stock)))
      end
    end

    context 'when a StandardError is raised' do
      it 'returns error: true and logs the error' do
        allow(mock_anthropic_client).to receive(:messages)
          .and_raise(StandardError.new('unexpected failure'))

        result = monitor.run

        expect(result[:error]).to be true
        expect(result[:turns]).to eq(0)
        expect(result[:log].any? { |l| l.include?('Agent error') }).to be true
      end
    end
  end

  describe 'tool methods' do
    let(:product) { create(:product, shop: shop, title: 'Test Widget') }
    let(:supplier) { create(:supplier, shop: shop, name: 'Acme Co', email: 'acme@example.com') }
    let(:variant_low) do
      create(:variant, shop: shop, product: product, sku: 'TW-LOW', title: 'Small', price: 10.00, supplier: supplier)
    end
    let(:variant_oos) do
      create(:variant, shop: shop, product: product, sku: 'TW-OOS', title: 'Large', price: 20.00, supplier: supplier)
    end
    let(:variant_ok) { create(:variant, shop: shop, product: product, sku: 'TW-OK', title: 'Medium', price: 15.00) }

    before do
      create(:inventory_snapshot, shop: shop, variant: variant_low, available: 5, on_hand: 5)
      create(:inventory_snapshot, shop: shop, variant: variant_oos, available: 0, on_hand: 0)
      create(:inventory_snapshot, shop: shop, variant: variant_ok, available: 50, on_hand: 50)
    end

    describe '#tool_check_inventory (via execute_tool)' do
      it 'returns flagged variants with their details' do
        result = monitor.send(:tool_check_inventory)

        expect(result).to include('flagged variants')
        expect(result).to include('TW-LOW')
        expect(result).to include('TW-OOS')
        expect(result).not_to include('TW-OK')
      end

      it 'includes status and supplier info' do
        result = monitor.send(:tool_check_inventory)

        expect(result).to include('low_stock')
        expect(result).to include('out_of_stock')
        expect(result).to include('Acme Co')
      end

      it 'returns healthy message when no flagged variants' do
        # Remove low/OOS snapshots and create healthy ones
        InventorySnapshot.delete_all
        create(:inventory_snapshot, shop: shop, variant: variant_low, available: 50, on_hand: 50)
        create(:inventory_snapshot, shop: shop, variant: variant_oos, available: 50, on_hand: 50)

        result = monitor.send(:tool_check_inventory)

        expect(result).to include('All SKUs are healthy')
      end
    end

    describe '#tool_get_stock_summary' do
      it 'returns summary with total, healthy, low, and OOS counts' do
        result = monitor.send(:tool_get_stock_summary)

        expect(result).to include('Total SKUs:')
        expect(result).to include('Healthy:')
        expect(result).to include('Low stock:')
        expect(result).to include('Out of stock:')
        expect(result).to include(shop.shop_domain)
      end
    end

    describe '#tool_send_alerts' do
      it 'sends alerts for all flagged variants when variant_ids is empty' do
        alert_sender = instance_double(Notifications::AlertSender)
        allow(Notifications::AlertSender).to receive(:new).with(shop).and_return(alert_sender)
        allow(alert_sender).to receive(:send_low_stock_alerts)

        result = monitor.send(:tool_send_alerts, { 'variant_ids' => [] })

        expect(result).to include('Sent alerts for')
        expect(alert_sender).to have_received(:send_low_stock_alerts)
      end

      it 'sends alerts only for specified variant_ids' do
        alert_sender = instance_double(Notifications::AlertSender)
        allow(Notifications::AlertSender).to receive(:new).with(shop).and_return(alert_sender)
        allow(alert_sender).to receive(:send_low_stock_alerts)

        result = monitor.send(:tool_send_alerts, { 'variant_ids' => [variant_low.id] })

        expect(result).to include('Sent alerts for 1 variant(s)')
        expect(alert_sender).to have_received(:send_low_stock_alerts) do |targets|
          expect(targets.size).to eq(1)
          expect(targets.first[:variant].id).to eq(variant_low.id)
        end
      end

      it 'returns message when no matching variant IDs found' do
        result = monitor.send(:tool_send_alerts, { 'variant_ids' => [999_999] })

        expect(result).to include('No matching variants')
      end

      it 'returns message when no flagged variants exist' do
        InventorySnapshot.delete_all
        create(:inventory_snapshot, shop: shop, variant: variant_low, available: 50, on_hand: 50)
        create(:inventory_snapshot, shop: shop, variant: variant_oos, available: 50, on_hand: 50)

        # Clear the flagged cache
        new_monitor = described_class.new(shop)
        result = new_monitor.send(:tool_send_alerts, { 'variant_ids' => [] })

        expect(result).to include('No flagged variants')
      end
    end

    describe '#tool_get_recent_alerts' do
      it "returns today's alerts" do
        create(:alert, shop: shop, variant: variant_low, alert_type: 'low_stock',
                       triggered_at: Time.current, current_quantity: 5)

        result = monitor.send(:tool_get_recent_alerts)

        expect(result).to include('alert(s) sent today')
        expect(result).to include('TW-LOW')
      end

      it 'returns no alerts message when none exist today' do
        result = monitor.send(:tool_get_recent_alerts)

        expect(result).to include('No alerts sent today')
      end

      it 'limits to 20 alerts' do
        25.times do
          v = create(:variant, shop: shop, product: product, sku: "BULK-#{SecureRandom.hex(3)}", title: 'Bulk')
          create(:alert, shop: shop, variant: v, alert_type: 'low_stock',
                         triggered_at: Time.current, current_quantity: 2)
        end

        result = monitor.send(:tool_get_recent_alerts)

        expect(result).to include('20 alert(s) sent today')
      end
    end

    describe '#tool_draft_purchase_order' do
      it 'creates a draft PO with line items for the supplier' do
        result = monitor.send(:tool_draft_purchase_order, { 'supplier_id' => supplier.id })

        expect(result).to include('Drafted PO')
        expect(result).to include('Acme Co')
        expect(result).to include('draft')

        po = PurchaseOrder.last
        expect(po.supplier).to eq(supplier)
        expect(po.status).to eq('draft')
        expect(po.line_items.size).to be >= 1
      end

      it 'calculates correct suggested quantities' do
        monitor.send(:tool_draft_purchase_order, { 'supplier_id' => supplier.id })

        line_item = PurchaseOrderLineItem.find_by(sku: 'TW-LOW')
        if line_item
          # threshold=10, available=5 => max(10*2-5, 10) = max(15, 10) = 15
          expect(line_item.qty_ordered).to eq(15)
        end
      end

      it 'returns not found message for invalid supplier' do
        result = monitor.send(:tool_draft_purchase_order, { 'supplier_id' => 999_999 })

        expect(result).to include('not found')
      end

      it 'returns message when supplier has no low-stock variants' do
        other_supplier = create(:supplier, shop: shop, name: 'Other Co')

        result = monitor.send(:tool_draft_purchase_order, { 'supplier_id' => other_supplier.id })

        expect(result).to include('No low-stock variants')
      end
    end
  end

  describe '#execute_tool (private)' do
    it 'handles unknown tool names gracefully' do
      tool_call = { 'id' => 'toolu_unknown', 'name' => 'nonexistent_tool', 'input' => {} }

      result = monitor.send(:execute_tool, tool_call)

      expect(result[:content]).to include('Unknown tool')
    end
  end
end
