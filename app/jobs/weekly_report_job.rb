class WeeklyReportJob < ApplicationJob
  queue_as :reports

  retry_on Net::SMTPError, wait: 5.minutes, attempts: 3

  def perform(shop_id)
    shop = Shop.active.find(shop_id)
    week_start = Time.current.beginning_of_week(:monday)

    ActsAsTenant.with_tenant(shop) do
      report = WeeklyReport.find_or_initialize_by(shop: shop, week_start: week_start)
      payload = Reports::WeeklyGenerator.new(shop, week_start).generate

      begin
        ai_commentary = AI::InsightsGenerator.new(shop).generate
        payload["ai_commentary"] = ai_commentary
      rescue StandardError => e
        Rails.logger.warn("[WeeklyReportJob] AI insights failed: #{e.message}")
      end

      report.payload = payload
      report.save!

      if shop.alert_email.present? && report.emailed_at.nil?
        ReportMailer.weekly_summary(report, shop.alert_email).deliver_later
        report.update!(emailed_at: Time.current)
      end
    end
  end
end
