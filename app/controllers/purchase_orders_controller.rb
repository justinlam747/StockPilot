class PurchaseOrdersController < ApplicationController
  def index
    @purchase_orders = PurchaseOrder.includes(:supplier).order(created_at: :desc).page(params[:page]).per(25)
  end

  def show
    @purchase_order = PurchaseOrder.includes(:purchase_order_line_items).find(params[:id])
  end

  def mark_sent
    @po = PurchaseOrder.find(params[:id])
    @po.update!(status: "sent")
    redirect_to purchase_order_path(@po), notice: "Marked as sent"
  end

  def mark_received
    @po = PurchaseOrder.find(params[:id])
    @po.update!(status: "received")
    redirect_to purchase_order_path(@po), notice: "Marked as received"
  end

  def generate_draft
    AuditLog.record(action: "po_draft_generated", shop: current_shop, request: request)

    generator = AI::PoDraftGenerator.new(current_shop)
    @draft = generator.call

    if request.headers["HX-Request"]
      render partial: "draft_preview", locals: { draft: @draft }
    else
      redirect_to purchase_orders_path, notice: "Draft generated"
    end
  end
end
