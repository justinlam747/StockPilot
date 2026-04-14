# frozen_string_literal: true

# Catalog product records are the main input for Catalog::AuditService.
# Keep this model narrow: tenant scoping, product identity, and the fields the
# audit rules still read.
class Product < ApplicationRecord
  acts_as_tenant :shop

  has_many :variants, dependent: :destroy

  validates :shopify_product_id, presence: true, if: -> { source == 'shopify' }
  validates :title, presence: true, length: { maximum: 500 }

  scope :active, -> { where(deleted_at: nil) }
end
