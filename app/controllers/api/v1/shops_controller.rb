module Api
  module V1
    class ShopsController < AuthenticatedController
      def show
        flagged = Inventory::LowStockDetector.new(current_shop).detect

        low_stock_items = flagged.first(5).map do |fv|
          {
            id: fv[:variant].id,
            sku: fv[:variant].sku,
            title: "#{fv[:variant].product.title} — #{fv[:variant].title}",
            available: fv[:available],
            threshold: fv[:threshold]
          }
        end

        render json: {
          total_skus: Variant.joins(:product).where(products: { deleted_at: nil }).count,
          low_stock_count: flagged.count { |fv| fv[:status] == :low_stock },
          out_of_stock_count: flagged.count { |fv| fv[:status] == :out_of_stock },
          synced_at: current_shop.synced_at,
          low_stock_items: low_stock_items
        }
      end

      def update
        current_shop.update!(shop_params)
        render json: current_shop
      end

      private

      def shop_params
        params.require(:shop).permit(:plan, settings: {})
      end
    end
  end
end
