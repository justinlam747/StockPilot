# frozen_string_literal: true

# A specific SKU/option combination of a product.
class Variant < ApplicationRecord
  acts_as_tenant :shop

  # attr_accessor creates a getter/setter pair that exists only in Ruby memory — not in the database.
  # Use it for computed, temporary, or cached values that you don't want to persist.
  # Here, current_stock is populated by the controller to avoid loading full snapshot history.
  # Populated by InventoryController#preload_current_stock to hold the latest available quantity.
  attr_accessor :current_stock

  belongs_to :product
  belongs_to :supplier, optional: true
  has_many :inventory_snapshots, dependent: :destroy
  has_many :alerts, dependent: :destroy
  # dependent: :restrict_with_error prevents this variant from being deleted if related line items exist.
  # Rails raises an error on delete — useful to prevent orphaning related records in critical workflows.
  has_many :purchase_order_line_items, dependent: :restrict_with_error

  validates :shopify_variant_id, presence: true, if: -> { source == 'shopify' }
  validates :price, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :low_stock_threshold, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
end
