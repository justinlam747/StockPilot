module Api
  module V1
    class ReportsController < AuthenticatedController
      def index
        reports = WeeklyReport.order(week_start: :desc)
                              .page(params[:page]).per(params[:per_page] || 25)

        render json: {
          reports: reports.as_json(only: [:id, :week_start, :created_at, :emailed_at],
                                   methods: [],
                                   include: {}),
          meta: {
            current_page: reports.current_page,
            total_pages: reports.total_pages,
            total_count: reports.total_count,
            per_page: reports.limit_value
          }
        }
      end

      def show
        report = WeeklyReport.find(params[:id])
        render json: report
      end

      def generate
        WeeklyReportJob.perform_later(current_shop.id)
        render json: { status: "queued" }, status: :accepted
      end
    end
  end
end
