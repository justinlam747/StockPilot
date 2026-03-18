# frozen_string_literal: true

# Represents a Shopify product synced from the store.
class Product < ApplicationRecord
  acts_as_tenant :shop

  has_many :variants, dependent: :destroy

  validates :shopify_product_id, presence: true
  validates :title, presence: true, length: { maximum: 500 }

  scope :active, -> { where(deleted_at: nil) }
end
