# frozen_string_literal: true

module Agents
  # Reviews current inventory risk and records operator-facing recommendations.
  class InventoryMonitor
    def initialize(shop, summary_client: SummaryClient.new(shop))
      @shop = shop
      @summary_client = summary_client
    end

    def execute(run)
      @run = run
      @logger = RunLogger.new(run)

      @logger.log_progress!(
        phase: 'Gathering inventory context',
        percent: 10,
        content: "Starting inventory monitor for #{@shop.shop_domain}."
      )
      @logger.log_message!(content: @run.goal, role: 'user', event_type: 'goal') if @run.goal.present?
      log_correction_note!

      flagged = apply_correction_rules!(detect_flagged_variants)
      metrics = build_metrics(flagged)

      @logger.log_progress!(
        phase: 'Evaluating stock risk',
        percent: 35,
        content: "Detected #{metrics['flagged_count']} flagged SKU(s)."
      )
      @logger.log_message!(
        content: "#{metrics.dig('counts', 'low_stock')} low-stock and #{metrics.dig('counts', 'out_of_stock')} out-of-stock SKU(s) identified.",
        metadata: { counts: metrics['counts'] }
      )

      supplier_reorders, supplierless = partition_reorders(flagged)
      out_of_stock = flagged.select { |row| row[:status] == :out_of_stock }

      @logger.log_progress!(
        phase: 'Drafting proposed actions',
        percent: 65,
        content: 'Building reorder and follow-up recommendations.'
      )
      create_actions!(supplier_reorders, supplierless, out_of_stock)

      summary_context = build_summary_context(metrics, supplier_reorders, supplierless)
      @logger.log_progress!(
        phase: 'Writing run summary',
        percent: 85,
        content: 'Preparing operator summary.'
      )
      summary = @summary_client.generate(summary_context)
      @logger.log_message!(
        content: summary,
        event_type: 'summary',
        metadata: { provider: @summary_client.provider_name }
      )

      @run.update!(
        status: 'completed',
        current_phase: 'Completed',
        progress_percent: 100,
        finished_at: Time.current,
        turns_count: correction_note.present? ? 2 : 1,
        summary: summary,
        result_payload: summary_context['result_payload']
      )
      @logger.log_progress!(phase: 'Completed', percent: 100, content: 'Agent run completed.')

      summary
    end

    private

    def correction_note
      @correction_note ||= @run.input_payload['correction'].presence
    end

    def log_correction_note!
      return if correction_note.blank?

      @logger.log_message!(
        content: correction_note,
        role: 'user',
        event_type: 'correction',
        metadata: { parent_run_id: @run.parent_run_id }
      )
    end

    def detect_flagged_variants
      flagged = Inventory::LowStockDetector.new(@shop).detect
      preload_variants(flagged)
      flagged.sort_by { |row| [status_weight(row[:status]), row[:available].to_i] }
    end

    def apply_correction_rules!(flagged)
      rules = correction_rules
      return flagged if rules.empty?

      filtered = flagged
      filtered = filtered.select { |row| row[:status] == :out_of_stock } if rules.include?('only_out_of_stock')
      filtered = filtered.select { |row| row[:status] == :low_stock } if rules.include?('only_low_stock')
      filtered = filtered.reject { |row| row[:variant].supplier.blank? } if rules.include?('ignore_supplierless')

      @logger.log_message!(
        content: "Applied correction rules: #{rules.join(', ').tr('_', ' ')}.",
        role: 'system',
        event_type: 'correction_applied',
        metadata: { rules: rules, parent_run_id: @run.parent_run_id }
      )

      filtered
    end

    def correction_rules
      text = correction_note.to_s.downcase
      return [] if text.blank?

      rules = []
      rules << 'ignore_supplierless' if text.match?(/ignore.*supplierless|ignore.*without supplier|ignore.*no supplier|skip.*supplierless|exclude.*supplierless/)
      rules << 'only_out_of_stock' if text.match?(/only .*out[- ]of[- ]stock|focus .*out[- ]of[- ]stock/)
      rules << 'only_low_stock' if text.match?(/only .*low[- ]stock|focus .*low[- ]stock/)
      rules
    end

    def preload_variants(flagged)
      variants = flagged.map { |row| row[:variant] }
      return if variants.empty?

      ActiveRecord::Associations::Preloader.new(records: variants, associations: %i[product supplier]).call
    end

    def status_weight(status)
      status == :out_of_stock ? 0 : 1
    end

    def build_metrics(flagged)
      {
        'flagged_count' => flagged.size,
        'counts' => {
          'low_stock' => flagged.count { |row| row[:status] == :low_stock },
          'out_of_stock' => flagged.count { |row| row[:status] == :out_of_stock },
          'supplierless' => flagged.count { |row| row[:variant].supplier.blank? }
        },
        'top_items' => flagged.first(5).map { |row| serialize_flagged_variant(row) }
      }
    end

    def partition_reorders(flagged)
      with_supplier, without_supplier = flagged.partition { |row| row[:variant].supplier.present? }
      [with_supplier.group_by { |row| row[:variant].supplier }, without_supplier]
    end

    def create_actions!(supplier_reorders, supplierless, out_of_stock)
      supplier_reorders.each do |supplier, rows|
        @logger.propose_action!(
          action_type: 'reorder_review',
          title: "Review reorder for #{supplier.name}",
          details: "Review #{rows.size} flagged SKU(s) for #{supplier.name} and convert them into a purchase order draft if approved.",
          payload: {
            supplier_id: supplier.id,
            supplier_name: supplier.name,
            supplier_email: supplier.email,
            items: rows.map { |row| serialize_reorder_item(row) }
          }
        )
      end

      return if supplierless.empty? && out_of_stock.empty?

      if supplierless.any?
        @logger.propose_action!(
          action_type: 'supplier_assignment',
          title: 'Assign suppliers to flagged SKUs',
          details: "#{supplierless.size} flagged SKU(s) do not have a supplier assigned yet.",
          payload: { items: supplierless.first(10).map { |row| serialize_reorder_item(row) } }
        )
      end

      return unless out_of_stock.any?

      @logger.propose_action!(
        action_type: 'urgent_restock',
        title: 'Escalate out-of-stock items',
        details: "#{out_of_stock.size} SKU(s) are already at zero available inventory.",
        payload: { items: out_of_stock.first(10).map { |row| serialize_reorder_item(row) } }
      )
    end

    def build_summary_context(metrics, supplier_reorders, supplierless)
      supplierless_items = supplierless.first(10).map { |row| serialize_reorder_item(row) }
      supplier_recommendations = supplier_reorders.map do |supplier, rows|
        {
          'supplier_name' => supplier.name,
          'supplier_email' => supplier.email,
          'item_count' => rows.size,
          'items' => rows.first(5).map { |row| serialize_reorder_item(row) }
        }
      end

      result_payload = {
        'shop_domain' => @shop.shop_domain,
        'goal' => @run.goal,
        'correction' => correction_note,
        'previous_summary' => @run.parent_run&.summary,
        'counts' => metrics['counts'],
        'flagged_count' => metrics['flagged_count'],
        'top_items' => metrics['top_items'],
        'supplier_recommendations' => supplier_recommendations,
        'supplierless_items' => supplierless_items
      }.compact

      {
        'shop_domain' => @shop.shop_domain,
        'goal' => @run.goal,
        'correction' => correction_note,
        'previous_summary' => @run.parent_run&.summary,
        'counts' => metrics['counts'],
        'flagged_count' => metrics['flagged_count'],
        'top_items' => metrics['top_items'],
        'supplier_recommendations' => supplier_recommendations,
        'supplierless_items' => supplierless_items,
        'result_payload' => result_payload
      }.compact
    end

    def serialize_flagged_variant(row)
      variant = row[:variant]
      {
        'sku' => variant.sku,
        'variant_title' => variant.title,
        'product_title' => variant.product&.title,
        'supplier_name' => variant.supplier&.name,
        'available' => row[:available],
        'threshold' => row[:threshold],
        'status' => row[:status].to_s
      }
    end

    def serialize_reorder_item(row)
      serialize_flagged_variant(row).merge('suggested_qty' => suggested_qty(row))
    end

    def suggested_qty(row)
      threshold = row[:threshold].to_i
      [threshold, (threshold * 2) - row[:available].to_i].max
    end
  end
end
