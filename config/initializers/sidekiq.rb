Sidekiq.configure_server do |config|
  config.redis = { url: ENV.fetch("REDIS_URL", "redis://localhost:6379/0") }

  config.on(:startup) do
    schedule = {
      "daily_sync" => {
        "cron" => "0 */4 * * *",
        "class" => "DailySyncAllShopsJob",
        "description" => "Sync inventory for all active shops"
      },
      "weekly_reports" => {
        "cron" => "0 * * * *",
        "class" => "WeeklyReportAllShopsJob",
        "description" => "Enqueue weekly reports (timezone-aware)"
      },
      "snapshot_cleanup" => {
        "cron" => "0 3 * * *",
        "class" => "SnapshotCleanupJob",
        "description" => "Delete snapshots older than 90 days"
      }
    }
    Sidekiq::Cron::Job.load_from_hash(schedule)
  end
end

Sidekiq.configure_client do |config|
  config.redis = { url: ENV.fetch("REDIS_URL", "redis://localhost:6379/0") }
end
