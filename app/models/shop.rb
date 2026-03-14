class Shop < ApplicationRecord
  encrypts :access_token

  has_many :products, dependent: :destroy
  has_many :variants, dependent: :destroy
  has_many :inventory_snapshots, dependent: :destroy
  has_many :suppliers, dependent: :destroy
  has_many :alerts, dependent: :destroy
  has_many :purchase_orders, dependent: :destroy
  has_many :audit_logs, dependent: :destroy

  scope :active, -> { where(uninstalled_at: nil) }

  def timezone
    settings["timezone"] || "America/Toronto"
  end

  def low_stock_threshold
    settings["low_stock_threshold"] || 10
  end

  def alert_email
    settings["alert_email"]
  end
end
