# frozen_string_literal: true

# A Shopify merchant store — the tenant root for all scoped data.
class Shop < ApplicationRecord
  encrypts :access_token

  belongs_to :user, optional: true

  has_many :products, dependent: :destroy
  has_many :variants, dependent: :destroy
  has_many :inventory_snapshots, dependent: :destroy
  has_many :suppliers, dependent: :destroy
  has_many :alerts, dependent: :destroy
  has_many :purchase_orders, dependent: :destroy
  has_many :audit_logs, dependent: :destroy

  DOMAIN_FORMAT = /\A[a-z0-9-]+\.myshopify\.com\z/i

  validates :shop_domain, presence: true, uniqueness: true,
                          format: { with: DOMAIN_FORMAT, message: 'must be a valid myshopify.com domain' }
  validates :access_token, presence: true, unless: :uninstalled?

  scope :active, -> { where(uninstalled_at: nil) }

  def uninstalled?
    uninstalled_at.present?
  end

  def timezone
    settings['timezone'] || 'America/Toronto'
  end

  def low_stock_threshold
    settings['low_stock_threshold'] || 10
  end

  def alert_email
    settings['alert_email']
  end

  # AI provider settings — keys stored encrypted in settings JSONB
  def llm_provider
    settings['llm_provider'] || ENV.fetch('LLM_PROVIDER', 'openai')
  end

  def llm_model
    settings['llm_model'] || ENV.fetch('LLM_MODEL', 'gpt-4o')
  end

  def llm_api_key(provider = nil)
    provider ||= llm_provider
    key_field = "#{provider}_api_key"
    settings[key_field].presence || env_api_key(provider)
  end

  def update_setting(key, value)
    self.settings = settings.merge(key => value)
    save!
  end

  private

  def env_api_key(provider)
    case provider
    when 'openai' then ENV['OPENAI_API_KEY']
    when 'anthropic' then ENV['ANTHROPIC_API_KEY']
    when 'google' then ENV['GOOGLE_API_KEY']
    end
  end
end
