# frozen_string_literal: true

class DashboardController < ApplicationController
  def index
    stats = shop_cache.inventory_stats
    @total_products = stats[:total_products]
    @low_stock = stats[:low_stock]
    @out_of_stock = stats[:out_of_stock]
    @pending_pos = stats[:pending_pos]
    @recent_alerts = Alert.includes(variant: :product).order(created_at: :desc).limit(10)
    @last_run = current_shop.last_agent_results
    @last_run_at = current_shop.last_agent_run_at
  end

  def run_agent
    AuditLog.record(action: 'agent_run', shop: current_shop, request: request)

    detector = Inventory::LowStockDetector.new(current_shop)
    low_stock_variants = detector.detect

    results = { low_stock_count: low_stock_variants.size, ran_at: Time.current.iso8601 }
    current_shop.update!(last_agent_run_at: Time.current, last_agent_results: results)

    if request.headers['HX-Request']
      render partial: 'agent_results', locals: { results: results }
    else
      redirect_to '/dashboard', notice: 'Agent run complete'
    end
  rescue StandardError => e
    Rails.logger.error("[DashboardController#run_agent] Error: #{e.message}")
    Sentry.capture_exception(e) if defined?(Sentry)
    redirect_to '/dashboard', alert: 'Agent run failed. Please try again.'
  end
end
