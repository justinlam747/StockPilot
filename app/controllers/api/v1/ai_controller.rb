module Api
  module V1
    class AiController < AuthenticatedController
      def insights
        result = AI::InsightsGenerator.new(current_shop).generate
        render json: { insights: result }
      end
    end
  end
end
