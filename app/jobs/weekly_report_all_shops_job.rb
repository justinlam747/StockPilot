class WeeklyReportAllShopsJob < ApplicationJob
  queue_as :reports

  def perform
    week_start = Time.current.beginning_of_week(:monday)

    Shop.active.find_each do |shop|
      tz = ActiveSupport::TimeZone[shop.timezone] || ActiveSupport::TimeZone["America/Toronto"]
      now_in_tz = Time.current.in_time_zone(tz)

      report_day = shop.settings["weekly_report_day"] || "monday"
      next unless now_in_tz.strftime("%A").downcase == report_day.downcase
      next unless now_in_tz.hour == 8

      existing = WeeklyReport.find_by(shop_id: shop.id, week_start: week_start)
      next if existing

      WeeklyReportJob.perform_later(shop.id)
    end
  end
end
