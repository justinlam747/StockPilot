# frozen_string_literal: true

# Merchant settings — thresholds, notifications.
class SettingsController < ApplicationController
  before_action :require_shop!

  def show; end

  def update
    updates = {}
    updates['timezone'] = params[:timezone] if params[:timezone].present?
    updates['low_stock_threshold'] = params[:low_stock_threshold].to_i if params[:low_stock_threshold].present?
    updates['alert_email'] = params[:alert_email] if params.key?(:alert_email)

    current_shop.update!(settings: current_shop.settings.merge(updates))
    AuditLog.record(action: 'settings_updated', shop: current_shop, request: request)

    if request.headers['HX-Request']
      render partial: 'saved_notice'
    else
      redirect_to '/settings', notice: 'Settings saved'
    end
  end
end
