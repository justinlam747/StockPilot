# frozen_string_literal: true

# Merchant settings for the lean catalog workflow.
class SettingsController < ApplicationController
  before_action :require_shop!, only: :update

  def show; end

  def update
    updates = {}
    updates['timezone'] = params[:timezone] if params[:timezone].present?

    current_shop.update!(settings: current_shop.settings.merge(updates))
    AuditLog.record(action: 'settings_updated', shop: current_shop, request: request)

    if request.headers['HX-Request']
      # HTMX requests swap this fragment into the notice container on the
      # settings page. Keep the response self-contained so save feedback works
      # without a separate partial.
      render html: helpers.content_tag(:div, 'Settings saved', class: 'flash flash--notice', role: 'status')
    else
      redirect_to '/settings', notice: 'Settings saved'
    end
  end
end
