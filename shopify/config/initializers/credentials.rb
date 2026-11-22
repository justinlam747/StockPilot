required = %w[SHOPIFY_API_KEY SHOPIFY_API_SECRET SHOPIFY_APP_URL DATABASE_URL
              ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY
              ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT]
required << 'SECRET_KEY_BASE' if Rails.env.production?
missing = required.select { |key| ENV[key].blank? }
raise "Missing connector settings: #{missing.join(', ')}" if missing.any?

app_url = URI.parse(ENV.fetch('SHOPIFY_APP_URL'))
unless app_url.is_a?(URI::HTTPS) || (app_url.is_a?(URI::HTTP) && %w[localhost 127.0.0.1].include?(app_url.host))
  raise 'SHOPIFY_APP_URL must use HTTPS or a local loopback URL for development'
end
Rails.application.config.x.shopify_url = app_url.origin
Rails.application.config.hosts << app_url.host

encryption = Rails.application.config.active_record.encryption
encryption.primary_key = ENV.fetch('ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY')
encryption.deterministic_key = ENV.fetch('ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY')
encryption.key_derivation_salt = ENV.fetch('ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT')
