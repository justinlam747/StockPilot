module Api
  module V1
    class AlertsController < AuthenticatedController
      def index
        alerts = Alert.order(triggered_at: :desc)
                      .page(params[:page]).per(params[:per_page] || 25)

        render json: {
          alerts: alerts.as_json(include: { variant: { include: :product } }),
          meta: {
            current_page: alerts.current_page,
            total_pages: alerts.total_pages,
            total_count: alerts.total_count,
            per_page: alerts.limit_value
          }
        }
      end

      def update
        alert = Alert.find(params[:id])
        alert.update!(alert_params)
        render json: alert
      end

      private

      def alert_params
        params.require(:alert).permit(:status)
      end
    end
  end
end
