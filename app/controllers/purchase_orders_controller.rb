# frozen_string_literal: true

# CRUD and lifecycle management for purchase orders (draft, send, receive).
class PurchaseOrdersController < ApplicationController
  before_action :require_shop!

  def index
    scope = PurchaseOrder.includes(:supplier, :line_items)
    scope = scope.where(status: params[:status]) if PurchaseOrder::STATUSES.include?(params[:status])
    @purchase_orders = scope.order(created_at: :desc).page(params[:page]).per(25)
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

  private

  def detect_low_stock
    Inventory::LowStockDetector.new(current_shop).detect
  end
end
