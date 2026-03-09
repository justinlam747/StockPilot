class WeeklyReportJob < ApplicationJob
  queue_as :reports

  retry_on Net::SMTPError, wait: 5.minutes, attempts: 3

  def perform(shop_id)
    raise NotImplementedError
  end
end
