# frozen_string_literal: true

class PurchaseOrdersController < ApplicationController
  def index
    @purchase_orders = PurchaseOrder.includes(:supplier,
                                              :line_items).order(created_at: :desc).page(params[:page]).per(25)
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

    generator = AI::PoDraftGenerator.new
    flagged = Inventory::LowStockDetector.new(current_shop).detect
    if flagged.empty?
      redirect_to purchase_orders_path, notice: 'No low-stock items to reorder'
      return
    end

    @draft = generator.generate(
      supplier: flagged.first[:variant].supplier || Supplier.first,
      line_items: flagged,
      shop: current_shop
    )

    if request.headers['HX-Request']
      render partial: 'draft_preview', locals: { draft: @draft }
    else
      redirect_to purchase_orders_path, notice: 'Draft generated'
    end
  rescue StandardError => e
    Rails.logger.error("[PurchaseOrdersController#generate_draft] Error: #{e.message}")
    Sentry.capture_exception(e) if defined?(Sentry)
    redirect_to purchase_orders_path, alert: 'Failed to generate draft. Please try again.'
  end
end
