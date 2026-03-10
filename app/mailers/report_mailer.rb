class ReportMailer < ApplicationMailer
  def weekly_summary(report, to)
    @report = report
    @payload = report.payload
    mail(
      to: to,
      subject: "[#{report.shop.shop_domain}] Weekly Inventory Report — #{report.week_start.strftime('%b %d, %Y')}"
    )
  end
end
