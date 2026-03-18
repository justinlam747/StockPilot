# frozen_string_literal: true

# Delivers weekly inventory summary reports to merchants.
class ReportMailer < ApplicationMailer
  def weekly_summary(shop, report_data)
    @shop = shop
    @report = report_data
    mail(
      to: shop.alert_email,
      subject: "[#{shop.shop_domain}] Weekly Inventory Report — #{Date.current.strftime('%b %d, %Y')}"
    )
  end
end
