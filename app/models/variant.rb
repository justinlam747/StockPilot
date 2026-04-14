# frozen_string_literal: true

# Catalog variant records feed the audit service and the Shopify Admin links.
# Keep the model focused on the product relation and the fields the active
# audit rules still inspect.
class Variant < ApplicationRecord
  acts_as_tenant :shop

  belongs_to :product

  validates :shopify_variant_id, presence: true, if: -> { source == 'shopify' }
  validates :price, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
end
