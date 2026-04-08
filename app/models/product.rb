# frozen_string_literal: true

# Represents a Shopify product synced from the store.
class Product < ApplicationRecord
  # acts_as_tenant :shop automatically scopes all queries to the current shop.
  # Without this, a query like Product.all would return products from ALL shops,
  # causing data leakage. With it, Product.all is rewritten as Product.where(shop_id: current_shop.id).
  acts_as_tenant :shop

  has_many :variants, dependent: :destroy

  validates :shopify_product_id, presence: true, if: -> { source == 'shopify' }
  validates :title, presence: true, length: { maximum: 500 }

  # Scope is a named query shortcut — a reusable WHERE clause stored as a method.
  # Product.active calls this lambda, applying the filter where(deleted_at: nil).
  # Scopes are chainable: Product.active.where(title: 'Shirt') combines both conditions.
  scope :active, -> { where(deleted_at: nil) }
end
