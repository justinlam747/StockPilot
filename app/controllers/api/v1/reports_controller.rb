module Api
  module V1
    class ReportsController < AuthenticatedController
      def index
        render json: []
      end

      def show
        render json: {}
      end

      def generate
        render json: { status: "queued" }
      end
    end
  end
end
