class WeeklyReportAllShopsJob < ApplicationJob
  queue_as :reports

  def perform
    raise NotImplementedError
  end
end
