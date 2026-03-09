module Api
  module V1
    class AiController < AuthenticatedController
      def insights
        render json: {}
      end
    end
  end
end
