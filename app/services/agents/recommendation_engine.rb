# frozen_string_literal: true

module Agents
  # Builds deterministic inventory recommendations from current stock, suppliers,
  # thresholds, alerts, and lightweight shop preferences.
  # rubocop:disable Metrics/ClassLength
  class RecommendationEngine
    # Immutable return object for one recommendation engine pass.
    class Result
      attr_reader :recommendations, :flagged, :correction_rules, :counts, :top_items, :supplier_recommendations,
                  :supplierless_items, :result_payload

      def initialize(attributes)
        @recommendations = attributes.fetch(:recommendations)
        @flagged = attributes.fetch(:flagged)
        @correction_rules = attributes.fetch(:correction_rules)
        @counts = attributes.fetch(:counts)
        @top_items = attributes.fetch(:top_items)
        @supplier_recommendations = attributes.fetch(:supplier_recommendations)
        @supplierless_items = attributes.fetch(:supplierless_items)
        @result_payload = attributes.fetch(:result_payload)
      end
    end

    class << self
      def call(shop:, goal: nil, correction: nil)
        new(shop, goal: goal, correction: correction).call
      end
    end

    def initialize(shop, goal: nil, correction: nil)
      @shop = shop
      @goal = goal
      @correction = correction.to_s
    end

    def call
      flagged = apply_correction_rules(detect_flagged_variants)
      recommendations = build_recommendations(flagged)
      counts = build_counts(flagged, recommendations)
      top_items = flagged.first(5).map { |row| serialize_flagged_variant(row) }
      supplier_recommendations = build_supplier_recommendations(recommendations)
      supplierless_items = flagged.select { |row| supplier_for(row[:variant]).blank? }
                                  .first(10)
                                  .map { |row| serialize_reorder_item(row) }

      Result.new(
        recommendations: recommendations,
        flagged: flagged,
        correction_rules: correction_rules,
        counts: counts,
        top_items: top_items,
        supplier_recommendations: supplier_recommendations,
        supplierless_items: supplierless_items,
        result_payload: build_result_payload(
          flagged: flagged,
          recommendations: recommendations,
          counts: counts,
          top_items: top_items,
          supplier_recommendations: supplier_recommendations,
          supplierless_items: supplierless_items
        )
      )
    end

    private

    attr_reader :shop, :goal, :correction

    def detect_flagged_variants
      flagged = Inventory::LowStockDetector.new(shop).detect
      preload_variants(flagged)
      flagged.reject { |row| ignored_sku?(row[:variant]) }
             .sort_by { |row| [status_weight(row[:status]), row[:available].to_i] }
    end

    def preload_variants(flagged)
      variants = flagged.pluck(:variant)
      return if variants.empty?

      ActiveRecord::Associations::Preloader.new(records: variants, associations: %i[product supplier]).call
    end

    def apply_correction_rules(flagged)
      rules = correction_rules
      return flagged if rules.empty?

      filtered = flagged
      filtered = filtered.select { |row| row[:status] == :out_of_stock } if rules.include?('only_out_of_stock')
      filtered = filtered.select { |row| row[:status] == :low_stock } if rules.include?('only_low_stock')
      filtered = filtered.reject { |row| supplier_for(row[:variant]).blank? } if rules.include?('ignore_supplierless')
      filtered
    end

    def correction_rules
      return @correction_rules if defined?(@correction_rules)

      text = correction.downcase
      @correction_rules = []
      if text.match?(/ignore.*supplierless|ignore.*without supplier|ignore.*no supplier|skip.*supplierless|exclude.*supplierless/)
        @correction_rules << 'ignore_supplierless'
      end
      @correction_rules << 'only_out_of_stock' if text.match?(/only .*out[- ]of[- ]stock|focus .*out[- ]of[- ]stock/)
      @correction_rules << 'only_low_stock' if text.match?(/only .*low[- ]stock|focus .*low[- ]stock/)
      @correction_rules
    end

    def build_recommendations(flagged)
      recommendations = []
      grouped_items = Hash.new { |hash, supplier| hash[supplier] = [] }

      flagged.each do |row|
        variant = row[:variant]
        supplier = supplier_for(variant)

        if supplier.blank?
          recommendations << supplier_assignment_recommendation(row)
        else
          item = serialize_reorder_item(row, supplier: supplier)
          recommendations << reorder_recommendation(row, item, supplier)
          grouped_items[supplier] << item
        end

        threshold_action = threshold_adjustment_recommendation(row)
        recommendations << threshold_action if threshold_action
      end

      grouped_items.each do |supplier, items|
        recommendations << purchase_order_draft_recommendation(supplier, items)
        recommendations << supplier_grouping_recommendation(supplier, items) if items.size > 1
      end

      recommendations
    end

    def reorder_recommendation(row, item, supplier)
      {
        action_type: 'reorder_recommendation',
        title: "Reorder #{item['sku'] || 'SKU'} from #{supplier.name}",
        details: reorder_reason(row, supplier),
        payload: item.merge(
          'supplier_id' => supplier.id,
          'supplier_name' => supplier.name,
          'supplier_email' => supplier.email,
          'items' => [item]
        )
      }
    end

    def supplier_assignment_recommendation(row)
      item = serialize_reorder_item(row)
      {
        action_type: 'supplier_assignment',
        title: "Assign a supplier to #{item['sku'] || 'flagged SKU'}",
        details: "#{item['sku'] || 'This SKU'} is #{item['status'].tr('_', ' ')} but has no supplier assigned.",
        payload: {
          'variant_id' => item['variant_id'],
          'sku' => item['sku'],
          'items' => [item]
        }
      }
    end

    def purchase_order_draft_recommendation(supplier, items)
      {
        action_type: 'purchase_order_draft',
        title: "Draft purchase order for #{supplier.name}",
        details: "Create a draft purchase order for #{items.size} flagged SKU(s) from #{supplier.name}.",
        payload: {
          'supplier_id' => supplier.id,
          'supplier_name' => supplier.name,
          'supplier_email' => supplier.email,
          'lead_time_days' => supplier.lead_time_days,
          'items' => items
        }
      }
    end

    def supplier_grouping_recommendation(supplier, items)
      {
        action_type: 'supplier_grouping',
        title: "Group #{items.size} #{supplier.name} SKUs into one PO",
        details: "#{items.size} flagged SKU(s) share #{supplier.name}; grouping them reduces manual PO work.",
        payload: {
          'supplier_id' => supplier.id,
          'supplier_name' => supplier.name,
          'supplier_email' => supplier.email,
          'lead_time_days' => supplier.lead_time_days,
          'items' => items
        }
      }
    end

    def threshold_adjustment_recommendation(row)
      alert_count = Alert.where(shop_id: shop.id, variant_id: row[:variant].id)
                         .where(triggered_at: 30.days.ago..)
                         .count
      return if alert_count < 3

      threshold = row[:threshold].to_i
      recommended_threshold = [(threshold * 1.5).ceil, threshold + 5].max
      item = serialize_flagged_variant(row)
      {
        action_type: 'threshold_adjustment',
        title: "Raise threshold for #{item['sku'] || 'flagged SKU'}",
        details: "#{item['sku'] || 'This SKU'} triggered #{alert_count} alert(s) in 30 days; consider a higher reorder point.",
        payload: item.merge(
          'current_threshold' => threshold,
          'recommended_threshold' => recommended_threshold,
          'alert_count_30d' => alert_count
        )
      }
    end

    def reorder_reason(row, supplier)
      available = row[:available].to_i
      threshold = row[:threshold].to_i
      lead_time = supplier.lead_time_days || 0
      "#{row[:variant].sku || 'This SKU'} has #{available} available against a threshold of #{threshold}; " \
        "#{supplier.name} has a #{lead_time}-day lead time."
    end

    def build_counts(flagged, recommendations)
      recommendation_counts = recommendations.group_by { |rec| rec[:action_type] }
                                             .transform_values(&:count)
      {
        'low_stock' => flagged.count { |row| row[:status] == :low_stock },
        'out_of_stock' => flagged.count { |row| row[:status] == :out_of_stock },
        'supplierless' => flagged.count { |row| supplier_for(row[:variant]).blank? },
        'recommendations' => recommendation_counts,
        'recommendation_total' => recommendations.size
      }
    end

    def build_supplier_recommendations(recommendations)
      recommendations.select { |rec| rec[:action_type] == 'purchase_order_draft' }.map do |rec|
        payload = rec[:payload]
        {
          'supplier_name' => payload['supplier_name'],
          'supplier_email' => payload['supplier_email'],
          'item_count' => Array(payload['items']).size,
          'items' => Array(payload['items']).first(5)
        }
      end
    end

    def build_result_payload(data)
      {
        'shop_domain' => shop.shop_domain,
        'goal' => goal,
        'correction' => correction.presence,
        'counts' => data.fetch(:counts),
        'flagged_count' => data.fetch(:flagged).size,
        'recommendation_count' => data.fetch(:recommendations).size,
        'recommendation_types' => data.dig(:counts, 'recommendations'),
        'top_items' => data.fetch(:top_items),
        'supplier_recommendations' => data.fetch(:supplier_recommendations),
        'supplierless_items' => data.fetch(:supplierless_items)
      }.compact
    end

    def serialize_reorder_item(row, supplier: nil)
      variant = row[:variant]
      threshold = row[:threshold].to_i
      available = row[:available].to_i
      {
        'variant_id' => variant.id,
        'product_id' => variant.product_id,
        'supplier_id' => supplier&.id,
        'supplier_name' => supplier&.name,
        'sku' => variant.sku,
        'product_title' => variant.product&.title,
        'variant_title' => variant.title,
        'current_quantity' => available,
        'available' => available,
        'on_hand' => row[:on_hand].to_i,
        'threshold' => threshold,
        'status' => row[:status].to_s,
        'recommended_quantity' => recommended_quantity(row),
        'suggested_qty' => recommended_quantity(row),
        'unit_price' => variant.price&.to_s,
        'recommendation_basis' => {
          'available' => available,
          'threshold' => threshold,
          'lead_time_days' => supplier&.lead_time_days,
          'target_days' => agent_preferences['default_reorder_days'].to_i,
          'min_order_qty' => agent_preferences['min_order_qty'].to_i
        }
      }
    end

    def serialize_flagged_variant(row)
      variant = row[:variant]
      {
        'variant_id' => variant.id,
        'sku' => variant.sku,
        'variant_title' => variant.title,
        'product_title' => variant.product&.title,
        'supplier_name' => supplier_for(variant)&.name,
        'available' => row[:available].to_i,
        'threshold' => row[:threshold].to_i,
        'status' => row[:status].to_s
      }
    end

    def supplier_for(variant)
      preferred_supplier_for(variant) || variant.supplier
    end

    def preferred_supplier_for(variant)
      preferred = agent_preferences['preferred_suppliers'] || {}
      supplier_id = preferred[variant.id.to_s] || preferred[variant.sku.to_s]
      return if supplier_id.blank?

      Supplier.where(shop_id: shop.id).find_by(id: supplier_id)
    end

    def ignored_sku?(variant)
      Array(agent_preferences['ignored_skus']).map(&:to_s).include?(variant.sku.to_s)
    end

    def recommended_quantity(row)
      threshold = row[:threshold].to_i
      available = row[:available].to_i
      base_quantity = [threshold, (threshold * 2) - available].max
      [base_quantity, agent_preferences['min_order_qty'].to_i].max
    end

    def agent_preferences
      @agent_preferences ||= shop.agent_preferences
    end

    def status_weight(status)
      status == :out_of_stock ? 0 : 1
    end
  end
  # rubocop:enable Metrics/ClassLength
end
