module Api
  module V1
    class ProductsController < AuthenticatedController
      def index
        products = Product.active.includes(:variants)

        if params[:filter] == "low_stock"
          flagged_ids = Inventory::LowStockDetector.new(current_shop).detect
                          .map { |fv| fv[:variant].product_id }.uniq
          products = products.where(id: flagged_ids)
        elsif params[:filter] == "out_of_stock"
          flagged_ids = Inventory::LowStockDetector.new(current_shop).detect
                          .select { |fv| fv[:status] == :out_of_stock }
                          .map { |fv| fv[:variant].product_id }.uniq
          products = products.where(id: flagged_ids)
        end

        products = products.page(params[:page]).per(params[:per_page] || 25)

        render json: {
          products: products.as_json(include: :variants),
          meta: {
            current_page: products.current_page,
            total_pages: products.total_pages,
            total_count: products.total_count,
            per_page: products.limit_value
          }
        }
      end

      def show
        product = Product.active.find(params[:id])
        render json: product.as_json(include: :variants)
      end
    end
  end
end
