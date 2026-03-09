module Api
  module V1
    class VariantsController < AuthenticatedController
      def index
        render json: []
      end

      def show
        render json: {}
      end

      def update
        render json: {}
      end
    end
  end
end
