class SnapshotCleanupJob < ApplicationJob
  queue_as :maintenance

  RETENTION_DAYS = 90

  def perform
    raise NotImplementedError
  end
end
