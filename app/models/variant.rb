class Variant < ApplicationRecord
  acts_as_tenant :shop

  belongs_to :product
  belongs_to :supplier, optional: true
  has_many :inventory_snapshots, dependent: :destroy
  has_many :alerts, dependent: :destroy
  has_many :purchase_order_line_items, dependent: :restrict_with_error

  def latest_snapshot
    inventory_snapshots.order(snapshotted_at: :desc).first
  end

  def inventory_quantity
    latest_snapshot&.available || 0
  end
end
