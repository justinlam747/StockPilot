module Api
  module V1
    class PurchaseOrdersController < AuthenticatedController
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

      def send_email
        render json: { status: "sent" }
      end

      def generate_draft
        render json: {}
      end
    end
  end
end
