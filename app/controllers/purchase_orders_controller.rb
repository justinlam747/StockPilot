# frozen_string_literal: true

# CRUD and lifecycle management for purchase orders (draft, send, receive).
class PurchaseOrdersController < ApplicationController
  def index
    @purchase_orders = PurchaseOrder.includes(:supplier, :line_items)
                                    .order(created_at: :desc)
                                    .page(params[:page]).per(25)
  end

  def show
    @purchase_order = PurchaseOrder.includes(line_items: { variant: :product }).find(params[:id])
  end

  def mark_sent
    @po = PurchaseOrder.find(params[:id])
    @po.update!(status: 'sent', sent_at: Time.current)
    AuditLog.record(action: 'po_marked_sent', shop: current_shop, request: request,
                    metadata: { purchase_order_id: @po.id })
    redirect_to purchase_order_path(@po), notice: 'Marked as sent'
  end

  def mark_received
    @po = PurchaseOrder.find(params[:id])
    @po.update!(status: 'received')
    AuditLog.record(action: 'po_marked_received', shop: current_shop, request: request,
                    metadata: { purchase_order_id: @po.id })
    redirect_to purchase_order_path(@po), notice: 'Marked as received'
  end

  def generate_draft
    AuditLog.record(action: 'po_draft_generated', shop: current_shop, request: request)
    flagged = detect_low_stock
    return redirect_to(purchase_orders_path, notice: 'No low-stock items to reorder') if flagged.empty?

    @draft = generate_ai_draft(flagged)
    respond_to_draft
  rescue StandardError => e
    handle_draft_error(e)
  end

  private

  def detect_low_stock
    Inventory::LowStockDetector.new(current_shop).detect
  end

  def generate_ai_draft(flagged)
    supplier = flagged.first[:variant].supplier || Supplier.first
    AI::PoDraftGenerator.new.generate(
      supplier: supplier, line_items: flagged, shop: current_shop
    )
  end

  def respond_to_draft
    if request.headers['HX-Request']
      render partial: 'draft_preview', locals: { draft: @draft }
    else
      redirect_to purchase_orders_path, notice: 'Draft generated'
    end
  end

  def handle_draft_error(err)
    Rails.logger.error("[PurchaseOrdersController#generate_draft] Error: #{err.message}")
    Sentry.capture_exception(err) if defined?(Sentry)
    redirect_to purchase_orders_path, alert: 'Failed to generate draft. Please try again.'
  end
end
