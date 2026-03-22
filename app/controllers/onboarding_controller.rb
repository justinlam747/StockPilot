# frozen_string_literal: true

# Three-step onboarding wizard for new users.
class OnboardingController < ApplicationController
  skip_before_action :require_onboarding
  skip_before_action :require_shop_connection
  layout 'onboarding'

  before_action :redirect_if_completed

  def index
    redirect_to onboarding_step_path(step: current_user.onboarding_step)
  end

  def show
    @step = params[:step].to_i
    redirect_to onboarding_step_path(step: current_user.onboarding_step) unless valid_step?(@step)
  end

  def update
    @step = params[:step].to_i
    case @step
    when 1 then process_step_1
    when 2 then process_step_2
    when 3 then process_step_3
    else redirect_to onboarding_path
    end
  end

  private

  def redirect_if_completed
    redirect_to '/dashboard' if current_user&.onboarding_completed?
  end

  def valid_step?(step)
    step >= 1 && step <= 3 && step <= current_user.onboarding_step
  end

  def process_step_1
    permitted = params.permit(:store_name, :store_category)
    current_user.update!(
      store_name: permitted[:store_name],
      store_category: permitted[:store_category],
      onboarding_step: 2
    )
    redirect_to onboarding_step_path(step: 2)
  end

  def process_step_2
    if params.permit(:skip)[:skip]
      current_user.update!(onboarding_step: 3)
      redirect_to onboarding_step_path(step: 3)
    else
      permitted = params.permit(:shop_domain)
      shop_domain = permitted[:shop_domain].to_s.strip.downcase
      session[:onboarding_return] = true
      session[:connecting_shop] = "#{shop_domain}.myshopify.com"
      redirect_to '/auth/shopify', allow_other_host: true,
                  params: { shop: "#{shop_domain}.myshopify.com" }
    end
  end

  def process_step_3
    permitted = params.permit(:threshold, channels: [])
    threshold = permitted[:threshold].to_i.clamp(1, 999)
    channels = Array(permitted[:channels]).select { |c| %w[in_app email].include?(c) }

    current_user.update!(
      onboarding_step: 4,
      onboarding_completed_at: Time.current
    )

    if current_shop
      current_shop.update_setting('low_stock_threshold', threshold)
      current_shop.update_setting('alert_channels', channels)
    end

    redirect_to '/dashboard'
  end
end
