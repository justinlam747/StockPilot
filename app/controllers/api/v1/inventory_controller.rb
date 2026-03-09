module Api
  module V1
    class InventoryController < AuthenticatedController
      def sync
        render json: { status: "queued" }
      end
    end
  end
end
