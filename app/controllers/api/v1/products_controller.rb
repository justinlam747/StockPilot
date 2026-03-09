module Api
  module V1
    class ProductsController < AuthenticatedController
      def index
        render json: []
      end

      def show
        render json: {}
      end
    end
  end
end
