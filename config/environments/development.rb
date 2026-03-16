require "active_support/core_ext/integer/time"

Rails.application.configure do
  config.enable_reloading = true
  config.eager_load = false
  config.consider_all_requests_local = true

  config.action_controller.perform_caching = true
  config.cache_store = :redis_cache_store, {
    url: ENV.fetch("REDIS_URL", "redis://localhost:6379/0"),
    expires_in: 1.hour,
    namespace: "cache",
    pool: false
  }

  config.active_storage.service = :local if defined?(ActiveStorage)

  config.action_mailer.raise_delivery_errors = false
  config.action_mailer.perform_caching = false
  config.action_mailer.delivery_method = :letter_opener_web if defined?(LetterOpenerWeb)

  config.active_support.deprecation = :log
  config.active_support.disallowed_deprecation = :raise
  config.active_support.disallowed_deprecation_warnings = []

  config.active_record.migration_error = :page_load
  config.active_record.verbose_query_logs = true

  # Allow ngrok and Cloudflare tunnel hosts in development
  config.hosts << /.*\.ngrok-free\.dev/
  config.hosts << /.*\.trycloudflare\.com/

  config.active_job.verbose_enqueue_logs = true

  config.active_record.encryption.primary_key = ENV.fetch("ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY", "dev-primary-key-that-is-long-enough")
  config.active_record.encryption.deterministic_key = ENV.fetch("ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY", "dev-deterministic-key-long-enough")
  config.active_record.encryption.key_derivation_salt = ENV.fetch("ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT", "dev-key-derivation-salt-long-enough")
end
