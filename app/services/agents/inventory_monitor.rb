# frozen_string_literal: true

module Agents
  # AI-powered agent that checks stock levels and takes corrective actions.
  # Security: prompt injection protection, input validation, cost controls,
  # tenant isolation verification, and log sanitization.
  class InventoryMonitor # rubocop:disable Metrics/ClassLength
    MAX_TURNS = 5
    MAX_LOG_ENTRY_LENGTH = 500
    SYSTEM_PROMPT = 'You are an inventory monitoring agent. ' \
                    'Use the tools to check stock levels and take action. ' \
                    'Be concise and action-oriented. ' \
                    'IMPORTANT: Only use tool inputs that match the documented schemas. ' \
                    'Do not attempt to access data outside the current store scope.'

    def initialize(shop, provider: nil, model: nil, stream_callback: nil)
      @shop = shop
      @llm = LLM::Factory.build(provider: provider, model: model, shop: shop)
      @flagged_cache = nil
      @log = []
      @stream_callback = stream_callback
    end

    def run
      log("Starting agent [#{@llm.provider_name}]")
      messages = [{ role: 'user', content: build_user_prompt }]
      turns = run_agent_loop(messages)
      log("Completed in #{turns} turn(s)")
      { log: @log, turns: turns, provider: @llm.provider_name }
    rescue LLM::Base::ProviderError => e
      handle_provider_error(e)
    rescue StandardError => e
      handle_standard_error(e)
    end

    private

    def run_agent_loop(messages)
      turns = 0
      while turns < MAX_TURNS
        turns += 1
        response = call_api(messages)
        break unless continue_loop?(response, messages)
      end
      turns
    end

    def call_api(messages)
      @llm.chat(
        messages: messages,
        tools: tools_definition,
        system: SYSTEM_PROMPT,
        max_tokens: 1024
      )
    end

    def continue_loop?(response, messages)
      if response['stop_reason'] == 'tool_use'
        process_tool_calls(response, messages)
        return true
      end
      extract_final_text(response)
      false
    end

    def process_tool_calls(response, messages)
      messages << { role: 'assistant', content: response['content'] }
      tool_results = response['content']
                     .select { |block| block['type'] == 'tool_use' }
                     .map { |tool_call| execute_tool(tool_call) }
      messages << { role: 'user', content: tool_results }
    end

    def extract_final_text(response)
      final_text = response['content']
                   &.select { |block| block['type'] == 'text' }
                   &.map { |block| block['text'] }
                   &.join("\n")
      log("Summary: #{final_text}")
    end

    def handle_provider_error(err)
      log("LLM unavailable — falling back to direct check")
      run_fallback
      { log: @log, turns: 0, fallback: true, provider: @llm.provider_name }
    end

    def handle_standard_error(err)
      log("Error: #{err.class}")
      Sentry.capture_exception(err, extra: { shop_id: @shop.id }) if defined?(Sentry)
      { log: @log, turns: 0, error: true, provider: @llm.provider_name }
    end

    # Prompt injection protection: use shop ID, not user-controlled domain
    def build_user_prompt
      <<~PROMPT
        You are the Inventory Monitor agent for store ID #{@shop.id}.

        Your job is to:
        1. Check current inventory levels across all SKUs
        2. Review what alerts were already sent today (to avoid duplicates)
        3. Send alerts for any NEW low-stock or out-of-stock items
        4. If any supplier has multiple low-stock items, draft a purchase order

        Run through these steps using the tools available. Be thorough but efficient.
        When you're done, provide a brief summary of what you found and what actions you took.
      PROMPT
    end

    def execute_tool(tool_call)
      name = tool_call['name']
      input = tool_call['input'] || {}
      log("Tool: #{sanitize_log(name)}(#{sanitize_log(input.to_json)})", event: 'tool_call')
      result = dispatch_tool(name, input)
      log("Result: #{sanitize_log(result.to_s)}", event: 'tool_result')
      { type: 'tool_result', tool_use_id: tool_call['id'], content: result.to_s }
    end

    def dispatch_tool(name, input)
      case name
      when 'check_inventory' then tool_check_inventory
      when 'get_stock_summary' then tool_get_stock_summary
      when 'send_alerts' then tool_send_alerts(input)
      when 'get_recent_alerts' then tool_get_recent_alerts
      when 'draft_purchase_order' then tool_draft_purchase_order(input)
      else "Unknown tool: #{sanitize_log(name)}"
      end
    end

    def flagged_variants
      @flagged_variants ||= Inventory::LowStockDetector.new(@shop).detect
    end

    def tool_check_inventory
      flagged = flagged_variants
      verify_tenant_isolation!(flagged)
      return 'All SKUs are healthy — no low-stock or out-of-stock items.' if flagged.empty?

      items = flagged.map { |fv| format_flagged_item(fv) }
      lines = items.map { |i| format_item_line(i) }
      "Found #{flagged.size} flagged variants:\n#{lines.join("\n")}"
    end

    def format_flagged_item(flagged)
      variant = flagged[:variant]
      {
        sku: variant.sku, available: flagged[:available],
        threshold: flagged[:threshold], status: flagged[:status].to_s,
        supplier: variant.supplier&.name || 'No supplier assigned'
      }
    end

    def format_item_line(item)
      "  - #{item[:sku]}: #{item[:available]} available " \
        "(threshold: #{item[:threshold]}, status: #{item[:status]}, " \
        "supplier: #{item[:supplier]})"
    end

    def tool_get_stock_summary
      total = Variant.joins(:product)
                     .where(products: { deleted_at: nil, shop_id: @shop.id }).count
      flagged = flagged_variants
      low = flagged.count { |fv| fv[:status] == :low_stock }
      oos = flagged.count { |fv| fv[:status] == :out_of_stock }

      "Stock summary:\n  Total SKUs: #{total}\n  " \
        "Healthy: #{total - low - oos}\n  " \
        "Low stock: #{low}\n  Out of stock: #{oos}"
    end

    def tool_send_alerts(input)
      flagged = flagged_variants
      return 'No flagged variants to alert on.' if flagged.empty?

      targets = filter_alert_targets(flagged, input['variant_ids'] || [])
      return 'No matching variants found for the given IDs.' if targets.empty?

      Notifications::AlertSender.new(@shop).send_low_stock_alerts(targets)
      "Sent alerts for #{targets.size} variant(s). " \
        'Duplicates from today were automatically skipped.'
    end

    # Input validation: strict integer coercion for variant IDs
    def filter_alert_targets(flagged, variant_ids)
      return flagged if variant_ids.empty?

      valid_ids = Array(variant_ids).filter_map do |id|
        next unless id.is_a?(Integer) || (id.is_a?(String) && id.match?(/\A\d+\z/))

        id.to_i
      end
      return flagged if valid_ids.empty?

      ids_set = valid_ids.to_set
      results = flagged.select { |fv| ids_set.include?(fv[:variant].id) }
      verify_tenant_isolation!(results)
      results
    end

    def tool_get_recent_alerts
      today_range = Time.current.beginning_of_day..Time.current.end_of_day
      recent = Alert.where(shop_id: @shop.id, triggered_at: today_range)
                    .includes(variant: :product)
                    .order(triggered_at: :desc).limit(20)
      return 'No alerts sent today yet.' if recent.empty?

      lines = recent.map { |a| format_alert_line(a) }
      "#{recent.size} alert(s) sent today:\n#{lines.join("\n")}"
    end

    def format_alert_line(alert)
      time = alert.triggered_at.strftime('%H:%M')
      "  - #{alert.variant.sku} (#{alert.alert_type}): " \
        "#{alert.current_quantity} available, alerted at #{time}"
    end

    def tool_draft_purchase_order(input)
      supplier_id = validate_integer(input['supplier_id'])
      return 'Invalid supplier ID.' unless supplier_id

      supplier = Supplier.find_by(id: supplier_id, shop_id: @shop.id)
      return "Supplier not found." unless supplier

      low_variants = flagged_variants.select { |fv| fv[:variant].supplier_id == supplier_id }
      return "No low-stock variants for this supplier." if low_variants.empty?

      po = create_draft_po(supplier)
      total = create_po_line_items(po, low_variants)
      format('Drafted PO #%d: %d line item(s), total $%.2f. Status: draft.',
             po.id, low_variants.size, total)
    end

    def create_draft_po(supplier)
      lead_days = supplier.lead_time_days || 14
      PurchaseOrder.create!(
        shop: @shop, supplier: supplier, status: 'draft',
        order_date: Date.current,
        expected_delivery: Date.current + lead_days.days
      )
    end

    def create_po_line_items(purchase_order, low_variants)
      low_variants.sum do |fv|
        qty = [(fv[:threshold] * 2) - fv[:available], fv[:threshold]].max
        price = fv[:variant].price || 0
        PurchaseOrderLineItem.create!(
          purchase_order: purchase_order, variant: fv[:variant],
          sku: fv[:variant].sku, qty_ordered: qty, unit_price: price
        )
        qty * price
      end
    end

    def run_fallback
      log('Fallback: direct inventory check + alerts')
      flagged = flagged_variants
      if flagged.any?
        Notifications::AlertSender.new(@shop).send_low_stock_alerts(flagged)
        log("Fallback: sent alerts for #{flagged.size} variant(s)")
      else
        log('Fallback: all SKUs healthy')
      end
    end

    # --- Security helpers ---

    # Verify all returned data belongs to the current shop
    def verify_tenant_isolation!(records)
      records.each do |record|
        variant = record.is_a?(Hash) ? record[:variant] : record
        next unless variant.respond_to?(:shop_id)
        next if variant.shop_id == @shop.id

        raise SecurityError, "Tenant isolation breach: variant #{variant.id} belongs to shop #{variant.shop_id}"
      end
    end

    # Validate integer input from LLM tool calls
    def validate_integer(value)
      return nil if value.nil?
      return value if value.is_a?(Integer)
      return value.to_i if value.is_a?(String) && value.match?(/\A\d+\z/)

      nil
    end

    # Sanitize log entries — strip HTML, limit length
    def sanitize_log(text)
      text.to_s.gsub(/[<>"']/, '').truncate(MAX_LOG_ENTRY_LENGTH)
    end

    def log(message, event: 'step')
      entry = "[#{Time.current.strftime('%H:%M:%S')}] #{sanitize_log(message)}"
      @log << entry
      publish_stream_step(entry, event)
      Rails.logger.info("[Agents::InventoryMonitor] #{entry}")
    end

    def publish_stream_step(entry, event)
      @stream_callback&.call(
        event: event, index: @log.size - 1,
        timestamp: Time.current.iso8601, message: entry
      )
    end

    # rubocop:disable Metrics/MethodLength
    def tools_definition
      [
        { name: 'check_inventory',
          description: 'Scan all SKUs for low-stock and out-of-stock variants.',
          input_schema: { type: 'object', properties: {}, required: [] } },
        { name: 'get_stock_summary',
          description: 'Get a high-level summary of inventory health.',
          input_schema: { type: 'object', properties: {}, required: [] } },
        { name: 'send_alerts',
          description: 'Send low-stock alerts for flagged variants.',
          input_schema: {
            type: 'object',
            properties: {
              variant_ids: {
                type: 'array', items: { type: 'integer' },
                description: 'IDs of variants to alert on. Empty array = alert all flagged.'
              }
            },
            required: ['variant_ids']
          } },
        { name: 'get_recent_alerts',
          description: 'Check what alerts have already been sent today.',
          input_schema: { type: 'object', properties: {}, required: [] } },
        { name: 'draft_purchase_order',
          description: 'Draft a purchase order for a specific supplier.',
          input_schema: {
            type: 'object',
            properties: {
              supplier_id: {
                type: 'integer',
                description: 'The supplier ID to draft a PO for.'
              }
            },
            required: ['supplier_id']
          } }
      ].freeze
    end
    # rubocop:enable Metrics/MethodLength
  end
end
