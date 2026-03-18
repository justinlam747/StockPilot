# frozen_string_literal: true

class WeeklyReportJob < ApplicationJob
  queue_as :default

  def perform(shop_id = nil)
    shops = shop_id ? Shop.active.where(id: shop_id) : Shop.active

    shops.find_each do |shop|
      ActsAsTenant.with_tenant(shop) do
        week_start = 1.week.ago.in_time_zone(shop.timezone).beginning_of_week
        report = Reports::WeeklyGenerator.new(shop, week_start).generate

        ReportMailer.weekly_summary(shop, report).deliver_later if shop.alert_email.present?

        Rails.logger.info("[WeeklyReportJob] Report generated for shop #{shop.id}")
      end
    rescue StandardError => e
      Rails.logger.error("[WeeklyReportJob] Failed for shop #{shop.id}: #{e.message}")
      Sentry.capture_exception(e) if defined?(Sentry)
    end
  end
end
