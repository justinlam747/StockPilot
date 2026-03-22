# frozen_string_literal: true

# Manages low-stock and out-of-stock alert display and dismissal.
class AlertsController < ApplicationController
  def index
    scope = Alert.includes(variant: :product).order(created_at: :desc)
    scope = apply_status_filter(scope)
    scope = apply_severity_filter(scope)
    @alerts = scope.page(params[:page]).per(25)
  end

  def dismiss
    alert = Alert.find(params[:id])
    alert.update!(dismissed: true)
    AuditLog.record(action: 'alert_dismissed', shop: current_shop, request: request,
                    metadata: { alert_id: alert.id, variant_id: alert.variant_id })
    if request.headers['HX-Request']
      render partial: 'alert_row', locals: { alert: alert.reload }
    else
      head :ok
    end
  end

  private

  def apply_status_filter(scope)
    case params[:status]
    when 'active' then scope.active
    when 'dismissed' then scope.dismissed
    else scope
    end
  end

  def apply_severity_filter(scope)
    case params[:severity]
    when 'critical' then scope.where(alert_type: 'out_of_stock')
    when 'warning' then scope.where(alert_type: 'low_stock')
    else scope
    end
  end
end
