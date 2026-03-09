module Api
  module V1
    class WebhookEndpointsController < AuthenticatedController
      def index
        render json: []
      end

      def show
        render json: {}
      end

      def create
        render json: {}, status: :created
      end

      def update
        render json: {}
      end

      def destroy
        head :no_content
      end
    end
  end
end
