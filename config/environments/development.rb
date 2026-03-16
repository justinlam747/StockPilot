require "active_support/core_ext/integer/time"

Rails.application.configure do
  config.enable_reloading = true
  config.eager_load = false
  config.consider_all_requests_local = true

  config.action_controller.perform_caching = false

  config.active_storage.service = :local if defined?(ActiveStorage)

  config.action_mailer.raise_delivery_errors = false
  config.action_mailer.perform_caching = false
  config.action_mailer.delivery_method = :letter_opener_web if defined?(LetterOpenerWeb)

  config.active_support.deprecation = :log
  config.active_support.disallowed_deprecation = :raise
  config.active_support.disallowed_deprecation_warnings = []

  config.active_record.migration_error = :page_load
  config.active_record.verbose_query_logs = true

  config.active_job.verbose_enqueue_logs = true

  # Active Record Encryption keys for development
  config.active_record.encryption.primary_key = "dev-primary-key-for-local-only"
  config.active_record.encryption.deterministic_key = "dev-deterministic-key-local-only"
  config.active_record.encryption.key_derivation_salt = "dev-key-derivation-salt-local"
end
