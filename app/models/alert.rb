# frozen_string_literal: true

# Tracks low-stock and out-of-stock notifications per variant.
class Alert < ApplicationRecord
  # acts_as_tenant :shop automatically scopes all queries to the current shop.
  # Without this, a query like Alert.all would return alerts from ALL shops,
  # causing data leakage. With it, Alert.all is rewritten as Alert.where(shop_id: current_shop.id).
  acts_as_tenant :shop

  belongs_to :variant

  validates :alert_type, presence: true, inclusion: { in: %w[low_stock out_of_stock] }
  validates :status, presence: true
  validates :channel, presence: true
  validates :threshold, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
  validates :current_quantity, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true

  scope :active, -> { where(dismissed: false) }
  scope :dismissed, -> { where(dismissed: true) }

  def severity
    case alert_type
    when 'out_of_stock' then 'critical'
    when 'low_stock' then 'warning'
    else 'info'
    end
  end

  def message
    variant_label = variant ? "#{variant.sku || 'Unknown SKU'} — #{variant.title}" : 'Unknown variant'
    case alert_type
    when 'out_of_stock'
      "#{variant_label} is out of stock"
    when 'low_stock'
      qty_text = current_quantity ? " (#{current_quantity} remaining)" : ''
      "#{variant_label} is low stock#{qty_text}"
    else
      "#{variant_label}: #{alert_type}"
    end
  end
end
