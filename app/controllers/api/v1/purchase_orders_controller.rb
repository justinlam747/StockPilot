module Api
  module V1
    class PurchaseOrdersController < AuthenticatedController
      def index
        pos = PurchaseOrder.includes(:supplier, :line_items)
                           .order(created_at: :desc)
                           .page(params[:page]).per(params[:per_page] || 25)

        render json: {
          purchase_orders: pos.as_json(include: [:supplier, :line_items]),
          meta: {
            current_page: pos.current_page,
            total_pages: pos.total_pages,
            total_count: pos.total_count,
            per_page: pos.limit_value
          }
        }
      end

      def show
        po = PurchaseOrder.includes(:supplier, :line_items).find(params[:id])
        render json: po.as_json(include: [:supplier, line_items: { include: :variant }])
      end

      def create
        po = PurchaseOrder.new(purchase_order_params)
        po.save!
        render json: po.as_json(include: :line_items), status: :created
      end

      def update
        po = PurchaseOrder.find(params[:id])
        po.update!(purchase_order_params)
        render json: po.as_json(include: :line_items)
      end

      def destroy
        po = PurchaseOrder.find(params[:id])
        po.destroy!
        head :no_content
      end

      def generate_draft
        supplier = Supplier.find(params[:supplier_id])
        flagged = Inventory::LowStockDetector.new(current_shop).detect
        supplier_variants = flagged.select { |fv| fv[:variant].supplier_id == supplier.id }

        po = PurchaseOrder.create!(
          supplier: supplier,
          status: "draft",
          order_date: Date.current,
          expected_delivery: Date.current + (supplier.lead_time_days || 14).days
        )

        supplier_variants.each do |fv|
          threshold = fv[:threshold]
          suggested_qty = [threshold * 2 - fv[:available], threshold].max

          po.line_items.create!(
            variant: fv[:variant],
            sku: fv[:variant].sku,
            quantity_ordered: suggested_qty,
            unit_price: fv[:variant].price
          )
        end

        begin
          draft_body = AI::PoDraftGenerator.new.generate(
            supplier: supplier,
            line_items: po.line_items.includes(:variant),
            shop: current_shop
          )
          po.update!(draft_body: draft_body)
        rescue StandardError => e
          Rails.logger.warn("[PO] AI draft generation failed: #{e.message}")
        end

        render json: po.as_json(include: :line_items), status: :created
      end

      def send_email
        po = PurchaseOrder.find(params[:id])
        PurchaseOrderMailer.send_po(po).deliver_later
        po.update!(status: "sent", sent_at: Time.current)
        render json: po
      end

      private

      def purchase_order_params
        params.require(:purchase_order).permit(
          :supplier_id, :status, :order_date, :expected_delivery, :notes, :draft_body,
          line_items_attributes: [:id, :variant_id, :sku, :quantity_ordered, :unit_price, :_destroy]
        )
      end
    end
  end
end
