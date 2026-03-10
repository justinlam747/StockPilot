module Api
  module V1
    class InventoryController < AuthenticatedController
      def sync
        InventorySyncJob.perform_later(current_shop.id)
        render json: { status: "queued" }, status: :accepted
      end
    end
  end
end
