# frozen_string_literal: true

# Merchant settings — AI provider config, thresholds, notifications.
class SettingsController < ApplicationController
  ALLOWED_PROVIDERS = %w[anthropic openai google].freeze
  ALLOWED_MODELS = {
    'anthropic' => %w[claude-sonnet-4-20250514 claude-haiku-4-5-20251001],
    'openai' => %w[gpt-4o gpt-4o-mini o3-mini],
    'google' => %w[gemini-2.0-flash gemini-2.5-pro-preview-06-05]
  }.freeze

  def show; end

  def update
    updates = {}
    updates['timezone'] = params[:timezone] if params[:timezone].present?
    updates['low_stock_threshold'] = params[:low_stock_threshold].to_i if params[:low_stock_threshold].present?
    updates['alert_email'] = params[:alert_email] if params.key?(:alert_email)
    updates.merge!(ai_settings)

    current_shop.update!(settings: current_shop.settings.merge(updates))
    AuditLog.record(action: 'settings_updated', shop: current_shop, request: request)

    if request.headers['HX-Request']
      render partial: 'saved_notice'
    else
      redirect_to '/settings', notice: 'Settings saved'
    end
  end

  private

  def ai_settings
    result = {}
    provider = params[:llm_provider]&.downcase&.strip
    model = params[:llm_model]&.strip

    if provider.present? && ALLOWED_PROVIDERS.include?(provider)
      result['llm_provider'] = provider
    end

    if model.present? && provider.present?
      allowed = ALLOWED_MODELS[provider] || []
      result['llm_model'] = model if allowed.include?(model)
    end

    # Store API keys — only update if provided (don't clear on blank)
    %w[anthropic openai google].each do |p|
      key_param = :"#{p}_api_key"
      next unless params[key_param].present?

      # Mask check: don't save if it's the masked placeholder
      next if params[key_param].start_with?('••••')

      result["#{p}_api_key"] = params[key_param].strip
    end

    result
  end
end
