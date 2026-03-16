class DashboardController < ApplicationController
  def index
    @total_products = Product.count
    variants_with_stock = Variant.includes(:inventory_snapshots).all
    @low_stock = variants_with_stock.count { |v| v.inventory_quantity.between?(1, 10) }
    @out_of_stock = variants_with_stock.count { |v| v.inventory_quantity == 0 }
    @total_variants = variants_with_stock.size
    @pending_pos = PurchaseOrder.where(status: "draft").count
    @sent_pos = PurchaseOrder.where(status: "sent").count
    @supplier_count = Supplier.count
    @recent_alerts = Alert.order(created_at: :desc).limit(5)
    @last_run = current_shop.last_agent_results
    @last_run_at = current_shop.last_agent_run_at
  end

  def run_agent
    AuditLog.record(action: "agent_run", shop: current_shop, request: request)

    results = { low_stock_count: 0, ran_at: Time.current.iso8601 }
    current_shop.update!(last_agent_run_at: Time.current, last_agent_results: results)

    if request.headers["HX-Request"]
      render partial: "agent_results", locals: { results: results }
    else
      redirect_to "/dashboard", notice: "Agent run complete"
    end
  end
end
