# frozen_string_literal: true

# Manages low-stock and out-of-stock alert display and dismissal.
class AlertsController < ApplicationController
  def index
    @alerts = Alert.includes(variant: :product).order(created_at: :desc).page(params[:page]).per(25)

    if params[:status] == 'active'
      @alerts = @alerts.active
    elsif params[:status] == 'dismissed'
      @alerts = @alerts.dismissed
    end
  end

  def dismiss
    alert = Alert.find(params[:id])
    alert.update!(dismissed: true)
    AuditLog.record(action: 'alert_dismissed', shop: current_shop, request: request,
                    metadata: { alert_id: alert.id, variant_id: alert.variant_id })
    head :ok
  end
end
