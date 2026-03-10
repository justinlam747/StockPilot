module Api
  module V1
    class SettingsController < AuthenticatedController
      ALLOWED_KEYS = %w[low_stock_threshold alert_email timezone weekly_report_day].freeze

      def show
        render json: {
          low_stock_threshold: current_shop.low_stock_threshold,
          alert_email: current_shop.alert_email,
          timezone: current_shop.timezone,
          weekly_report_day: current_shop.settings["weekly_report_day"] || "monday"
        }
      end

      def update
        permitted = settings_params.to_h.slice(*ALLOWED_KEYS)
        merged = current_shop.settings.merge(permitted)
        current_shop.update!(settings: merged)

        render json: {
          low_stock_threshold: current_shop.low_stock_threshold,
          alert_email: current_shop.alert_email,
          timezone: current_shop.timezone,
          weekly_report_day: current_shop.settings["weekly_report_day"] || "monday"
        }
      end

      private

      def settings_params
        params.require(:settings).permit(*ALLOWED_KEYS)
      end
    end
  end
end
