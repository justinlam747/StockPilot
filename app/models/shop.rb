# frozen_string_literal: true

# Tenant root for the lean catalog-audit app.
# Keep only the connection state, sync metadata, and settings that the
# active workflow still depends on.
class Shop < ApplicationRecord
  encrypts :access_token

  has_many :products, dependent: :destroy
  has_many :variants, dependent: :destroy
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

  def update_setting(key, value)
    self.settings = settings.merge(key => value)
    save!
  end
end
