# frozen_string_literal: true

# Generates and emails weekly inventory reports for active shops.
class WeeklyReportJob < ApplicationJob
  queue_as :default

  def perform(shop_id = nil)
    target_shops(shop_id).find_each { |shop| generate_report(shop) }
  end

  private

  def target_shops(shop_id)
    shop_id ? Shop.active.where(id: shop_id) : Shop.active
  end

  def generate_report(shop)
    ActsAsTenant.with_tenant(shop) { build_and_send_report(shop) }
  rescue StandardError => e
    Rails.logger.error("[WeeklyReportJob] Failed for shop #{shop.id}: #{e.message}")
    Sentry.capture_exception(e) if defined?(Sentry)
  end

  def build_and_send_report(shop)
    week_start = 1.week.ago.in_time_zone(shop.timezone).beginning_of_week
    report = Reports::WeeklyGenerator.new(shop, week_start).generate
    ReportMailer.weekly_summary(shop, report).deliver_later if shop.alert_email.present?
    Rails.logger.info("[WeeklyReportJob] Report generated for shop #{shop.id}")
  end
end
