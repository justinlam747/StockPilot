module Api
  module V1
    class AlertsController < AuthenticatedController
      def index
        render json: []
      end

      def update
        render json: {}
      end
    end
  end
end
