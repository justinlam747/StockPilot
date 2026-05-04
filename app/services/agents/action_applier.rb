# frozen_string_literal: true

module Agents
  # Applies accepted copilot actions through the same command path used by the UI.
  class ActionApplier
    APPLYABLE_STATUSES = %w[proposed edited accepted].freeze
    PURCHASE_ORDER_ACTIONS = %w[reorder_recommendation supplier_grouping purchase_order_draft].freeze

    # Machine-readable error payload for failed action application.
    class ApplicationError
      attr_reader :code, :reason, :remediation

      def initialize(code:, reason:, remediation:)
        @code = code
        @reason = reason
        @remediation = remediation
      end

      def message
        reason
      end

      def to_h
        { code: code, reason: reason, remediation: remediation }
      end
    end

    # Raised when an action cannot be applied with a machine-readable error payload.
    class ApplicationFailure < StandardError
      attr_reader :error

      def initialize(error)
        @error = error
        super(error.reason)
      end
    end

    class << self
      def call(action:, actor: nil, params: {})
        new(action, actor: actor, params: params).call
      end
    end

    def initialize(action, actor: nil, params: {})
      @action = action
      @run = action.agent_run
      @shop = action.agent_run.shop
      @actor = actor.presence || 'system'
      @params = params
    end

    def call
      validate_status!

      ActsAsTenant.with_tenant(shop) do
        ActiveRecord::Base.transaction do
          result = apply_by_type
          mark_applied!(result)
          PreferenceLearner.call(action: action, outcome: 'accepted')
          result
        end
      end
    rescue ApplicationFailure => e
      mark_failed!(e.error)
      raise
    rescue StandardError => e
      error = structured_error('APPLICATION_FAILED', e.message, 'Review the recommendation payload and try again.')
      mark_failed!(error)
      raise ApplicationFailure, error
    end

    private

    attr_reader :action, :run, :shop, :actor, :params

    def validate_status!
      return if APPLYABLE_STATUSES.include?(action.status)

      raise ApplicationFailure, structured_error(
        'INVALID_STATUS',
        "Cannot apply an action with status #{action.status}.",
        'Only proposed, edited, or accepted recommendations can be accepted.'
      )
    end

    def apply_by_type
      if PURCHASE_ORDER_ACTIONS.include?(action.action_type)
        create_purchase_order!
      elsif action.action_type == 'threshold_adjustment'
        apply_threshold_adjustment!
      elsif action.action_type == 'supplier_assignment'
        accept_manual_follow_up!
      else
        raise ApplicationFailure, structured_error(
          'UNSUPPORTED_ACTION',
          "#{action.action_type} cannot be applied automatically.",
          'Reject the action or handle it manually.'
        )
      end
    end

    def create_purchase_order!
      supplier = find_supplier!
      items = normalized_items
      raise_invalid_payload!('No purchase order line items were provided.') if items.empty?

      purchase_order = PurchaseOrder.create!(
        shop: shop,
        supplier: supplier,
        status: 'draft',
        order_date: Date.current,
        expected_delivery: expected_delivery_for(supplier),
        po_notes: "Generated from AI recommendation action ##{action.id}.",
        source: 'agent_action',
        source_agent_run: run,
        source_agent_action: action
      )

      items.each do |item|
        variant = find_variant!(item.fetch('variant_id'))
        purchase_order.line_items.create!(
          variant: variant,
          sku: item['sku'].presence || variant.sku,
          title: item['variant_title'].presence || variant.title,
          qty_ordered: item.fetch('recommended_quantity').to_i,
          unit_price: item['unit_price'].presence || variant.price
        )
      end

      AuditLog.record(
        action: 'agent_purchase_order_generated',
        shop: shop,
        metadata: {
          agent_run_id: run.id,
          agent_action_id: action.id,
          purchase_order_id: purchase_order.id,
          actor: actor
        }
      )
      purchase_order
    end

    def apply_threshold_adjustment!
      variant = find_variant!(action.payload['variant_id'])
      new_threshold = action.payload['recommended_threshold'].to_i
      raise_invalid_payload!('Recommended threshold must be greater than zero.') unless new_threshold.positive?

      old_threshold = variant.low_stock_threshold || shop.low_stock_threshold
      variant.update!(low_stock_threshold: new_threshold)
      AuditLog.record(
        action: 'agent_threshold_updated',
        shop: shop,
        metadata: {
          agent_run_id: run.id,
          agent_action_id: action.id,
          variant_id: variant.id,
          previous_threshold: old_threshold,
          new_threshold: new_threshold,
          actor: actor
        }
      )
      variant
    end

    def accept_manual_follow_up!
      AuditLog.record(
        action: 'agent_manual_follow_up_accepted',
        shop: shop,
        metadata: {
          agent_run_id: run.id,
          agent_action_id: action.id,
          action_type: action.action_type,
          actor: actor
        }
      )
      action
    end

    def mark_applied!(result)
      payload = action.payload.deep_dup
      payload['applied_purchase_order_id'] = result.id if result.is_a?(PurchaseOrder)
      payload['applied_variant_id'] = result.id if result.is_a?(Variant)

      action.update!(
        status: result == action ? 'accepted' : 'applied',
        payload: payload,
        resolved_at: Time.current,
        resolved_by: actor,
        resolution_note: resolution_note_for(result)
      )
      AuditLog.record(
        action: 'agent_recommendation_applied',
        shop: shop,
        metadata: {
          agent_run_id: run.id,
          agent_action_id: action.id,
          action_type: action.action_type,
          result_type: result.class.name,
          result_id: result.id,
          actor: actor
        }
      )
    end

    def mark_failed!(error)
      action.update!(
        status: 'failed',
        resolved_at: Time.current,
        resolved_by: actor,
        resolution_note: "#{error.code}: #{error.reason}"
      )
      AuditLog.record(
        action: 'agent_recommendation_apply_failed',
        shop: shop,
        metadata: {
          agent_run_id: run.id,
          agent_action_id: action.id,
          action_type: action.action_type,
          error: error.to_h,
          actor: actor
        }
      )
    end

    def resolution_note_for(result)
      case result
      when PurchaseOrder then "Created draft purchase order ##{result.id}."
      when Variant then "Updated threshold for #{result.sku || "variant ##{result.id}"}."
      else 'Accepted for manual follow-up.'
      end
    end

    def find_supplier!
      supplier_id = action.payload['supplier_id']
      supplier = Supplier.where(shop_id: shop.id).find_by(id: supplier_id)
      return supplier if supplier

      raise ApplicationFailure, structured_error(
        'SUPPLIER_NOT_FOUND',
        'The recommendation supplier could not be found for this shop.',
        'Edit the recommendation and choose a valid supplier.'
      )
    end

    def find_variant!(variant_id)
      variant = Variant.where(shop_id: shop.id).find_by(id: variant_id)
      return variant if variant

      raise ApplicationFailure, structured_error(
        'VARIANT_NOT_FOUND',
        'A recommendation line item references a variant outside this shop or a missing variant.',
        'Regenerate recommendations or remove the invalid line item.'
      )
    end

    def normalized_items
      raw_items = Array(action.payload['items'])
      raw_items = [action.payload] if raw_items.empty? && action.payload['variant_id'].present?

      raw_items.filter_map do |item|
        item = item.to_h.deep_stringify_keys
        quantity = item['recommended_quantity'].presence || item['suggested_qty']
        next if item['variant_id'].blank? || quantity.to_i <= 0

        item.merge('recommended_quantity' => quantity.to_i)
      end
    end

    def expected_delivery_for(supplier)
      return if supplier.lead_time_days.blank?

      Date.current + supplier.lead_time_days.days
    end

    def raise_invalid_payload!(reason)
      raise ApplicationFailure, structured_error('INVALID_PAYLOAD', reason, 'Edit the recommendation and try again.')
    end

    def structured_error(code, reason, remediation)
      ApplicationError.new(code: code, reason: reason, remediation: remediation)
    end
  end
end
