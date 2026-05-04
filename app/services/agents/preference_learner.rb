# frozen_string_literal: true

module Agents
  # Captures lightweight merchant preferences from recommendation outcomes.
  class PreferenceLearner
    MIN_REORDER_DAYS = 7
    MAX_REORDER_DAYS = 90

    class << self
      def call(action:, outcome:)
        new(action, outcome).call
      end
    end

    def initialize(action, outcome)
      @action = action
      @outcome = outcome.to_s
      @shop = action.agent_run.shop
    end

    def call
      return unless %w[accepted edited rejected].include?(outcome)

      updates = {}
      learn_reorder_window!(updates)
      learn_preferred_supplier!(updates)
      return if updates.empty?

      shop.update_agent_preferences!(updates)
      AuditLog.record(
        action: 'agent_preferences_updated',
        shop: shop,
        metadata: {
          agent_run_id: action.agent_run_id,
          agent_action_id: action.id,
          outcome: outcome,
          updates: updates
        }
      )
    end

    private

    attr_reader :action, :outcome, :shop

    def learn_reorder_window!(updates)
      original = original_quantity
      edited = edited_quantity
      return if original.blank? || edited.blank? || original.to_i == edited.to_i

      current_days = shop.agent_preferences['default_reorder_days'].to_i
      current_days = 30 if current_days <= 0
      next_days = edited.to_i > original.to_i ? current_days + 5 : current_days - 5
      updates['default_reorder_days'] = next_days.clamp(MIN_REORDER_DAYS, MAX_REORDER_DAYS)
    end

    def learn_preferred_supplier!(updates)
      supplier_id = merchant_overrides['supplier_id'] || action.payload['supplier_id']
      variant_id = primary_variant_id
      return if supplier_id.blank? || variant_id.blank?
      return unless Supplier.where(shop_id: shop.id).exists?(id: supplier_id)

      preferred = shop.agent_preferences['preferred_suppliers'] || {}
      updates['preferred_suppliers'] = preferred.merge(variant_id.to_s => supplier_id.to_i)
    end

    def original_quantity
      merchant_overrides['original_recommended_quantity'] ||
        action.payload.dig('recommendation_basis', 'original_recommended_quantity') ||
        action.payload['recommended_quantity'] ||
        first_item['recommended_quantity']
    end

    def edited_quantity
      merchant_overrides['recommended_quantity']
    end

    def primary_variant_id
      action.payload['variant_id'] || first_item['variant_id']
    end

    def first_item
      Array(action.payload['items']).first || {}
    end

    def merchant_overrides
      action.payload['merchant_overrides'] || {}
    end
  end
end
