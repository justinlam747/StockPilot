require "active_support/core_ext/integer/time"

Rails.application.configure do
  config.enable_reloading = false
  config.eager_load = ENV["CI"].present?
  config.consider_all_requests_local = true

  config.action_controller.perform_caching = false
  config.cache_store = :null_store

  config.action_dispatch.show_exceptions = :rescuable
  config.action_controller.allow_forgery_protection = false

  config.action_mailer.perform_caching = false
  config.action_mailer.delivery_method = :test

  config.active_support.deprecation = :stderr
  config.active_support.disallowed_deprecation = :raise

  config.active_job.queue_adapter = :test

  config.active_record.encryption.primary_key = "test-primary-key-that-is-long-enough"
  config.active_record.encryption.deterministic_key = "test-deterministic-key-long-enough"
  config.active_record.encryption.key_derivation_salt = "test-key-derivation-salt-long-enough"
end
