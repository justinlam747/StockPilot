# frozen_string_literal: true

# Purges inventory snapshots older than the retention period in batches.
class SnapshotCleanupJob < ApplicationJob
  queue_as :maintenance

  RETENTION_DAYS = 90
  BATCH_SIZE = 10_000

  def perform
    cutoff = RETENTION_DAYS.days.ago

    loop do
      deleted = InventorySnapshot.where(created_at: ...cutoff).limit(BATCH_SIZE).delete_all
      break if deleted < BATCH_SIZE
    end
  end
end
