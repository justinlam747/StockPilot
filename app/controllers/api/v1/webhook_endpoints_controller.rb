module Api
  module V1
    class WebhookEndpointsController < AuthenticatedController
      def index
        endpoints = WebhookEndpoint.page(params[:page]).per(params[:per_page] || 25)

        render json: {
          webhook_endpoints: endpoints,
          meta: {
            current_page: endpoints.current_page,
            total_pages: endpoints.total_pages,
            total_count: endpoints.total_count,
            per_page: endpoints.limit_value
          }
        }
      end

      def show
        endpoint = WebhookEndpoint.find(params[:id])
        render json: endpoint
      end

      def create
        endpoint = WebhookEndpoint.new(endpoint_params)
        endpoint.save!
        render json: endpoint, status: :created
      end

      def update
        endpoint = WebhookEndpoint.find(params[:id])
        endpoint.update!(endpoint_params)
        render json: endpoint
      end

      def destroy
        endpoint = WebhookEndpoint.find(params[:id])
        endpoint.destroy!
        head :no_content
      end

      private

      def endpoint_params
        params.require(:webhook_endpoint).permit(:url, :event_type, :is_active)
      end
    end
  end
end
