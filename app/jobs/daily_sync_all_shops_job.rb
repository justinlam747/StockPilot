class DailySyncAllShopsJob < ApplicationJob
  queue_as :default

  def perform
    raise NotImplementedError
  end
end
