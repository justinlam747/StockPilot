# frozen_string_literal: true

# Renders the merchant dashboard with inventory stats and agent results.
class DashboardController < ApplicationController
  def index
    load_dashboard_stats
    @recent_alerts = Alert.includes(variant: :product).order(created_at: :desc).limit(10)
    @last_run = current_shop.last_agent_results
    @last_run_at = current_shop.last_agent_run_at
  end

  def run_agent
    AuditLog.record(action: 'agent_run', shop: current_shop, request: request)
    results = execute_agent_run
    respond_to_agent_run(results)
  rescue StandardError => e
    handle_agent_error(e)
  end

  private

  def load_dashboard_stats
    stats = shop_cache.inventory_stats
    @total_products = stats[:total_products]
    @low_stock = stats[:low_stock]
    @out_of_stock = stats[:out_of_stock]
    @pending_pos = stats[:pending_pos]
    @total_suppliers = Supplier.where(shop_id: current_shop.id).count
    @total_alerts = Alert.where(shop_id: current_shop.id).count
    @total_variants = Variant.where(shop_id: current_shop.id).count
    @healthy_products = [@total_products - @low_stock - @out_of_stock, 0].max
    @health_pct = @total_products.positive? ? ((@healthy_products.to_f / @total_products) * 100).round : 0
    @sent_pos = PurchaseOrder.where(shop_id: current_shop.id, status: 'sent').count
    @alerts_today = Alert.where(shop_id: current_shop.id)
                        .where('created_at >= ?', Time.current.beginning_of_day).count
    @avg_variants_per_product = @total_products.positive? ? (@total_variants.to_f / @total_products).round(1) : 0
  end

  def execute_agent_run
    low_stock_variants = Inventory::LowStockDetector.new(current_shop).detect
    results = { low_stock_count: low_stock_variants.size, ran_at: Time.current.iso8601 }
    current_shop.update!(last_agent_run_at: Time.current, last_agent_results: results)
    results
  end

  def respond_to_agent_run(results)
    if request.headers['HX-Request']
      render partial: 'agent_results', locals: { results: results }
    else
      redirect_to '/dashboard', notice: 'Agent run complete'
    end
  end

  def handle_agent_error(err)
    Rails.logger.error("[DashboardController#run_agent] Error: #{err.message}")
    Sentry.capture_exception(err) if defined?(Sentry)
    redirect_to '/dashboard', alert: 'Agent run failed. Please try again.'
  end
end
