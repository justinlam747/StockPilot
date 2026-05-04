# frozen_string_literal: true

# A Shopify merchant store — the tenant root for all scoped data.
class Shop < ApplicationRecord
  DEFAULT_AGENT_PREFERENCES = {
    'default_reorder_days' => 30,
    'min_order_qty' => 0,
    'preferred_suppliers' => {},
    'ignored_skus' => []
  }.freeze

  # Rails 7+ encrypts :access_token stores the value encrypted in the database (as ciphertext),
  # but auto-decrypts it when you access the attribute in Ruby (shop.access_token returns plaintext).
  # Encryption happens on save, decryption on read. Requires RAILS_MASTER_KEY environment variable.
  # If the key is lost, encrypted data becomes unrecoverable.
  encrypts :access_token

  has_many :products, dependent: :destroy
  has_many :variants, dependent: :destroy
  has_many :inventory_snapshots, dependent: :destroy
  has_many :suppliers, dependent: :destroy
  has_many :alerts, dependent: :destroy
  has_many :purchase_orders, dependent: :destroy
  has_many :audit_logs, dependent: :destroy
  has_many :agent_runs, dependent: :destroy

  DOMAIN_FORMAT = /\A[a-z0-9-]+\.myshopify\.com\z/i

  validates :shop_domain, presence: true, uniqueness: true,
                          format: { with: DOMAIN_FORMAT, message: 'must be a valid myshopify.com domain' }
  validates :access_token, presence: true, unless: :uninstalled?

  scope :active, -> { where(uninstalled_at: nil) }

  def uninstalled?
    uninstalled_at.present?
  end

  # The methods below are named helpers that provide defaults when accessing the settings hash.
  # settings is stored as JSON in the database (Rails serializes/deserializes automatically).
  # Each helper provides a convenient way to read a setting with a fallback default value,
  # so callers don't have to worry about missing keys: timezone defaults to 'America/Toronto' if not set.
  def timezone
    settings['timezone'] || 'America/Toronto'
  end

  def low_stock_threshold
    settings['low_stock_threshold'] || 10
  end

  def alert_email
    settings['alert_email']
  end

  def agent_preferences
    DEFAULT_AGENT_PREFERENCES.deep_merge(settings['agent_preferences'] || {})
  end

  def update_agent_preferences!(updates)
    normalized = updates.deep_stringify_keys
    update!(settings: settings.merge('agent_preferences' => agent_preferences.deep_merge(normalized)))
  end

  def update_setting(key, value)
    self.settings = settings.merge(key => value)
    save!
  end
end
