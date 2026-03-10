module Api
  module V1
    class SuppliersController < AuthenticatedController
      def index
        suppliers = Supplier.page(params[:page]).per(params[:per_page] || 25)

        render json: {
          suppliers: suppliers,
          meta: {
            current_page: suppliers.current_page,
            total_pages: suppliers.total_pages,
            total_count: suppliers.total_count,
            per_page: suppliers.limit_value
          }
        }
      end

      def show
        supplier = Supplier.find(params[:id])
        render json: supplier
      end

      def create
        supplier = Supplier.new(supplier_params)
        supplier.save!
        render json: supplier, status: :created
      end

      def update
        supplier = Supplier.find(params[:id])
        supplier.update!(supplier_params)
        render json: supplier
      end

      def destroy
        supplier = Supplier.find(params[:id])
        supplier.destroy!
        head :no_content
      end

      private

      def supplier_params
        params.require(:supplier).permit(:name, :email, :contact_name, :lead_time_days, :notes)
      end
    end
  end
end
