module Api
  module V1
    class AiController < AuthenticatedController
      def insights
        result = AI::InsightsGenerator.new(current_shop).generate
        render json: { insights: result }
      end

      def agent_status
        today_range = Time.current.beginning_of_day..Time.current.end_of_day
        alerts_today = Alert.where(shop_id: current_shop.id, triggered_at: today_range).count
        flagged = Inventory::LowStockDetector.new(current_shop).detect

        render json: {
          low_stock_count: flagged.count { |fv| fv[:status] == :low_stock },
          out_of_stock_count: flagged.count { |fv| fv[:status] == :out_of_stock },
          alerts_sent_today: alerts_today,
          last_sync: current_shop.synced_at&.iso8601
        }
      end

      def run_agent
        AgentInventoryCheckJob.perform_later(current_shop.id)
        render json: { status: "queued", message: "Inventory agent check queued." }
      end
    end
  end
end
