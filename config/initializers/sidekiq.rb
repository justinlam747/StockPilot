Sidekiq.configure_server do |config|
  config.redis = { url: ENV.fetch("REDIS_URL", "redis://localhost:6379/0") }

  config.on(:startup) do
    schedule = {
      "daily_sync" => {
        "cron" => "0 */4 * * *",
        "class" => "DailySyncAllShopsJob",
        "description" => "Sync inventory for all active shops"
      },
      "snapshot_cleanup" => {
        "cron" => "0 3 * * *",
        "class" => "SnapshotCleanupJob",
        "description" => "Delete snapshots older than 90 days"
      },
      "agent_inventory_check" => {
        "cron" => "0 * * * *",
        "class" => "AgentInventoryCheckJob",
        "description" => "Run AI inventory monitor agent hourly for all shops"
      }
    }
    Sidekiq::Cron::Job.load_from_hash(schedule)
  end
end

Sidekiq.configure_client do |config|
  config.redis = { url: ENV.fetch("REDIS_URL", "redis://localhost:6379/0") }
end
