# frozen_string_literal: true

# A single SKU entry within a purchase order.
class PurchaseOrderLineItem < ApplicationRecord
  belongs_to :purchase_order
  belongs_to :variant

  validates :qty_ordered, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :qty_received, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :unit_price, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
end
