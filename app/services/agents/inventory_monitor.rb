# frozen_string_literal: true

module Agents
  class InventoryMonitor
    MODEL = 'claude-sonnet-4-20250514'
    MAX_TURNS = 10

    TOOLS = [
      {
        name: 'check_inventory',
        description: 'Scan all SKUs for low-stock and out-of-stock variants. Returns a list of flagged items with current quantity, threshold, and status.',
        input_schema: { type: 'object', properties: {}, required: [] }
      },
      {
        name: 'get_stock_summary',
        description: 'Get a high-level summary of inventory health: total SKUs, how many are low stock, out of stock, and healthy.',
        input_schema: { type: 'object', properties: {}, required: [] }
      },
      {
        name: 'send_alerts',
        description: "Send low-stock alerts for flagged variants. Deduplicates — won't alert the same SKU twice in one day. Creates alert records and fires webhooks.",
        input_schema: {
          type: 'object',
          properties: {
            variant_ids: {
              type: 'array',
              items: { type: 'integer' },
              description: 'IDs of variants to alert on. Pass an empty array to alert on ALL currently flagged variants.'
            }
          },
          required: ['variant_ids']
        }
      },
      {
        name: 'get_recent_alerts',
        description: 'Check what alerts have already been sent today to avoid duplicate notifications.',
        input_schema: { type: 'object', properties: {}, required: [] }
      },
      {
        name: 'draft_purchase_order',
        description: 'Draft a purchase order for a supplier based on their low-stock variants. Returns the drafted PO details.',
        input_schema: {
          type: 'object',
          properties: {
            supplier_id: {
              type: 'integer',
              description: 'The supplier ID to draft a PO for.'
            }
          },
          required: ['supplier_id']
        }
      }
    ].freeze

    def initialize(shop)
      @shop = shop
      @client = Anthropic::Client.new(api_key: ENV.fetch('ANTHROPIC_API_KEY'))
      @flagged_cache = nil
      @log = []
    end

    def run
      log("Starting inventory monitor agent for #{@shop.shop_domain}")

      messages = [
        {
          role: 'user',
          content: <<~PROMPT
            You are the Inventory Monitor agent for the Shopify store "#{@shop.shop_domain}".

            Your job is to:
            1. Check current inventory levels across all SKUs
            2. Review what alerts were already sent today (to avoid duplicates)
            3. Send alerts for any NEW low-stock or out-of-stock items
            4. If any supplier has multiple low-stock items, draft a purchase order

            Run through these steps using the tools available. Be thorough but efficient.
            When you're done, provide a brief summary of what you found and what actions you took.
          PROMPT
        }
      ]

      turns = 0
      while turns < MAX_TURNS
        turns += 1

        response = @client.messages(
          model: MODEL,
          max_tokens: 1024,
          system: 'You are an inventory monitoring agent. Use the tools to check stock levels and take action. Be concise and action-oriented.',
          tools: TOOLS,
          messages: messages
        )

        # Check if the model wants to use tools
        if response['stop_reason'] == 'tool_use'
          # Add assistant message
          messages << { role: 'assistant', content: response['content'] }

          # Process each tool call
          tool_results = response['content']
                         .select { |block| block['type'] == 'tool_use' }
                         .map { |tool_call| execute_tool(tool_call) }

          messages << { role: 'user', content: tool_results }
        else
          # Model is done — extract final text
          final_text = response['content']
                       &.select { |block| block['type'] == 'text' }
                       &.map { |block| block['text'] }
                       &.join("\n")

          log("Agent summary: #{final_text}")
          break
        end
      end

      log("Agent completed in #{turns} turn(s)")
      { log: @log, turns: turns }
    rescue Anthropic::Error => e
      log("Anthropic API error: #{e.message} — falling back to direct check")
      run_fallback
      { log: @log, turns: 0, fallback: true }
    rescue StandardError => e
      log("Agent error: #{e.class} — #{e.message}")
      Rails.logger.error("[Agents::InventoryMonitor] #{e.class}: #{e.message}\n#{e.backtrace&.first(5)&.join("\n")}")
      { log: @log, turns: 0, error: true }
    end

    private

    def execute_tool(tool_call)
      name = tool_call['name']
      input = tool_call['input'] || {}
      tool_use_id = tool_call['id']

      log("Tool call: #{name}(#{input.to_json})")

      result = case name
               when 'check_inventory' then tool_check_inventory
               when 'get_stock_summary' then tool_get_stock_summary
               when 'send_alerts' then tool_send_alerts(input)
               when 'get_recent_alerts' then tool_get_recent_alerts
               when 'draft_purchase_order' then tool_draft_purchase_order(input)
               else "Unknown tool: #{name}"
               end

      log("Tool result: #{result.to_s.truncate(200)}")

      {
        type: 'tool_result',
        tool_use_id: tool_use_id,
        content: result.to_s
      }
    end

    def flagged_variants
      @flagged_variants ||= Inventory::LowStockDetector.new(@shop).detect
    end

    def tool_check_inventory
      flagged = flagged_variants
      return 'All SKUs are healthy — no low-stock or out-of-stock items.' if flagged.empty?

      items = flagged.map do |fv|
        {
          variant_id: fv[:variant].id,
          sku: fv[:variant].sku,
          title: "#{fv[:variant].product.title} — #{fv[:variant].title}",
          available: fv[:available],
          threshold: fv[:threshold],
          status: fv[:status].to_s,
          supplier: fv[:variant].supplier&.name || 'No supplier assigned'
        }
      end

      "Found #{flagged.size} flagged variants:\n#{items.map do |i|
        "  - #{i[:sku]}: #{i[:available]} available (threshold: #{i[:threshold]}, status: #{i[:status]}, supplier: #{i[:supplier]})"
      end.join("\n")}"
    end

    def tool_get_stock_summary
      total = Variant.joins(:product).where(products: { deleted_at: nil, shop_id: @shop.id }).count
      flagged = flagged_variants
      low = flagged.count { |fv| fv[:status] == :low_stock }
      oos = flagged.count { |fv| fv[:status] == :out_of_stock }

      "Stock summary for #{@shop.shop_domain}:\n  Total SKUs: #{total}\n  Healthy: #{total - low - oos}\n  Low stock: #{low}\n  Out of stock: #{oos}"
    end

    def tool_send_alerts(input)
      flagged = flagged_variants
      return 'No flagged variants to alert on.' if flagged.empty?

      variant_ids = input['variant_ids'] || []
      targets = if variant_ids.empty?
                  flagged
                else
                  ids_set = variant_ids.to_set
                  flagged.select { |fv| ids_set.include?(fv[:variant].id) }
                end

      return 'No matching variants found for the given IDs.' if targets.empty?

      Notifications::AlertSender.new(@shop).send_low_stock_alerts(targets)
      "Sent alerts for #{targets.size} variant(s). Duplicates from today were automatically skipped."
    end

    def tool_get_recent_alerts
      today_range = Time.current.beginning_of_day..Time.current.end_of_day
      recent = Alert.where(shop_id: @shop.id, triggered_at: today_range)
                    .includes(variant: :product)
                    .order(triggered_at: :desc)
                    .limit(20)

      return 'No alerts sent today yet.' if recent.empty?

      lines = recent.map do |a|
        "  - #{a.variant.sku} (#{a.alert_type}): #{a.current_quantity} available, alerted at #{a.triggered_at.strftime('%H:%M')}"
      end

      "#{recent.size} alert(s) sent today:\n#{lines.join("\n")}"
    end

    def tool_draft_purchase_order(input)
      supplier_id = input['supplier_id']
      supplier = Supplier.find_by(id: supplier_id, shop_id: @shop.id)
      return "Supplier #{supplier_id} not found." unless supplier

      low_variants = flagged_variants.select { |fv| fv[:variant].supplier_id == supplier_id }
      return "No low-stock variants for supplier #{supplier.name}." if low_variants.empty?

      po = PurchaseOrder.create!(
        shop: @shop,
        supplier: supplier,
        status: 'draft',
        order_date: Date.current,
        expected_delivery: Date.current + (supplier.lead_time_days || 14).days
      )

      total = 0
      low_variants.each do |fv|
        qty = [fv[:threshold] * 2 - fv[:available], fv[:threshold]].max
        price = fv[:variant].price || 0
        PurchaseOrderLineItem.create!(
          purchase_order: po,
          variant: fv[:variant],
          sku: fv[:variant].sku,
          qty_ordered: qty,
          unit_price: price
        )
        total += qty * price
      end

      "Drafted PO ##{po.id} for #{supplier.name}: #{low_variants.size} line item(s), total $#{'%.2f' % total}. Status: draft (awaiting approval)."
    end

    # Fallback if Claude API is down — run the basic sync directly
    def run_fallback
      log('Running fallback: direct inventory check + alerts')
      flagged = flagged_variants
      if flagged.any?
        Notifications::AlertSender.new(@shop).send_low_stock_alerts(flagged)
        log("Fallback: sent alerts for #{flagged.size} variant(s)")
      else
        log('Fallback: all SKUs healthy')
      end
    end

    def log(message)
      entry = "[#{Time.current.strftime('%H:%M:%S')}] #{message}"
      @log << entry
      Rails.logger.info("[Agents::InventoryMonitor] #{entry}")
    end
  end
end
