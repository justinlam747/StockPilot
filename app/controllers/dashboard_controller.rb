class DashboardController < ApplicationController
  def index
    @total_products = Product.count
    latest_available = latest_snapshot_subquery
    @low_stock = Variant
      .joins("INNER JOIN (#{latest_available}) latest ON latest.variant_id = variants.id")
      .where("latest.available > 0 AND latest.available <= COALESCE(variants.low_stock_threshold, ?)", current_shop.low_stock_threshold)
      .count
    @out_of_stock = Variant
      .joins("INNER JOIN (#{latest_available}) latest ON latest.variant_id = variants.id")
      .where("latest.available <= 0")
      .count
    @pending_pos = PurchaseOrder.where(status: "draft").count
    @recent_alerts = Alert.order(created_at: :desc).limit(10)
    @last_run = current_shop.last_agent_results
    @last_run_at = current_shop.last_agent_run_at
  end

  def run_agent
    AuditLog.record(action: "agent_run", shop: current_shop, request: request)

    detector = Inventory::LowStockDetector.new(current_shop)
    low_stock_variants = detector.detect

    results = { low_stock_count: low_stock_variants.size, ran_at: Time.current.iso8601 }
    current_shop.update!(last_agent_run_at: Time.current, last_agent_results: results)

    if request.headers["HX-Request"]
      render partial: "agent_results", locals: { results: results }
    else
      redirect_to "/dashboard", notice: "Agent run complete"
    end
  end

  private

  def latest_snapshot_subquery
    InventorySnapshot
      .select("DISTINCT ON (variant_id) variant_id, available")
      .where(shop_id: current_shop.id)
      .order("variant_id, created_at DESC")
      .to_sql
  end
end
