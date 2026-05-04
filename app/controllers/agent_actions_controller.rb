# frozen_string_literal: true

# Human-in-the-loop controls for copilot recommendations.
class AgentActionsController < ApplicationController
  before_action :require_shop!
  before_action :set_action

  def accept
    result = Agents::ActionApplier.call(
      action: @action,
      actor: current_shop.shop_domain,
      params: action_params
    )
    redirect_to agent_path(@action.agent_run), notice: accept_notice(result)
  rescue Agents::ActionApplier::ApplicationFailure => e
    redirect_to agent_path(@action.agent_run), alert: e.error.reason
  end

  def reject
    unless @action.resolvable?
      redirect_to agent_path(@action.agent_run), alert: 'Only proposed or edited recommendations can be rejected.'
      return
    end

    @action.update!(
      status: 'rejected',
      feedback_note: params[:feedback_note],
      resolved_at: Time.current,
      resolved_by: current_shop.shop_domain,
      resolution_note: 'Rejected by merchant.'
    )
    Agents::PreferenceLearner.call(action: @action, outcome: 'rejected')
    AuditLog.record(
      action: 'agent_recommendation_rejected',
      shop: current_shop,
      request: request,
      metadata: audit_metadata.merge(feedback_note: params[:feedback_note])
    )

    redirect_to agent_path(@action.agent_run), notice: 'Recommendation rejected.'
  end

  def edit_recommendation
    unless @action.resolvable?
      redirect_to agent_path(@action.agent_run), alert: 'Only proposed or edited recommendations can be edited.'
      return
    end

    @action.update!(
      status: 'edited',
      payload: edited_payload,
      feedback_note: params[:feedback_note].presence || @action.feedback_note
    )
    Agents::PreferenceLearner.call(action: @action, outcome: 'edited')
    AuditLog.record(
      action: 'agent_recommendation_edited',
      shop: current_shop,
      request: request,
      metadata: audit_metadata.merge(feedback_note: params[:feedback_note])
    )

    redirect_to agent_path(@action.agent_run), notice: 'Recommendation updated.'
  rescue ActiveRecord::RecordNotFound
    redirect_to agent_path(@action.agent_run), alert: 'Choose a valid supplier for this shop.'
  rescue ActionController::BadRequest => e
    redirect_to agent_path(@action.agent_run), alert: e.message
  end

  private

  def set_action
    @action = AgentAction
              .joins(:agent_run)
              .where(agent_runs: { shop_id: current_shop.id })
              .find(params[:id])
  end

  def edited_payload
    payload = @action.payload.deep_dup
    overrides = payload['merchant_overrides'] || {}

    apply_quantity_edits!(payload, overrides)
    apply_supplier_edit!(payload, overrides)
    apply_threshold_edit!(payload, overrides)

    payload['merchant_overrides'] = overrides
    payload
  end

  def apply_quantity_edits!(payload, overrides)
    quantity = params[:recommended_quantity].presence
    if quantity
      quantity = positive_integer(quantity, 'Recommended quantity')
      overrides['original_recommended_quantity'] ||= payload['recommended_quantity'] || payload.dig('items', 0, 'recommended_quantity')
      overrides['recommended_quantity'] = quantity
      payload['recommended_quantity'] = quantity if payload.key?('recommended_quantity')
      Array(payload['items']).each { |item| item['recommended_quantity'] = quantity if item['recommended_quantity'].present? }
    end

    quantities = params[:quantities].to_unsafe_h if params[:quantities].respond_to?(:to_unsafe_h)
    return if quantities.blank?

    Array(payload['items']).each do |item|
      variant_id = item['variant_id'].to_s
      next if quantities[variant_id].blank?

      item['original_recommended_quantity'] ||= item['recommended_quantity']
      item['recommended_quantity'] = positive_integer(quantities[variant_id], 'Line quantity')
    end
  end

  def apply_supplier_edit!(payload, overrides)
    return if params[:supplier_id].blank?

    supplier = Supplier.where(shop_id: current_shop.id).find(params[:supplier_id])
    overrides['supplier_id'] = supplier.id
    payload['supplier_id'] = supplier.id
    payload['supplier_name'] = supplier.name
    payload['supplier_email'] = supplier.email
    Array(payload['items']).each do |item|
      item['supplier_id'] = supplier.id
      item['supplier_name'] = supplier.name
    end
  end

  def apply_threshold_edit!(payload, overrides)
    threshold = params[:recommended_threshold].presence
    return if threshold.blank?

    threshold = positive_integer(threshold, 'Recommended threshold')
    overrides['original_recommended_threshold'] ||= payload['recommended_threshold']
    overrides['recommended_threshold'] = threshold
    payload['recommended_threshold'] = threshold
  end

  def positive_integer(value, label)
    Integer(value).tap do |integer|
      raise ArgumentError, "#{label} must be greater than zero." unless integer.positive?
    end
  rescue ArgumentError => e
    raise ActionController::BadRequest, e.message
  end

  def action_params
    params.permit(:recommended_quantity, :recommended_threshold, :supplier_id, quantities: {})
  end

  def accept_notice(result)
    case result
    when PurchaseOrder then "Draft purchase order ##{result.id} created."
    when Variant then 'Variant threshold updated.'
    else 'Recommendation accepted.'
    end
  end

  def audit_metadata
    {
      agent_run_id: @action.agent_run_id,
      agent_action_id: @action.id,
      action_type: @action.action_type
    }
  end
end
