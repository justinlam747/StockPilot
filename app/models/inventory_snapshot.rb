# frozen_string_literal: true

# Point-in-time record of a variant's stock levels across all locations.
class InventorySnapshot < ApplicationRecord
  acts_as_tenant :shop

  belongs_to :variant

  validates :available, presence: true, numericality: { only_integer: true }
  validates :on_hand, presence: true, numericality: { only_integer: true }
  validates :committed, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :incoming, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
end
