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

  # Returns products that have at least one variant with low stock.
  # "Low stock" means: available > 0 but below the shop's threshold.
  #
  # How this works:
  # 1. We JOIN products to their variants
  # 2. We JOIN variants to their latest inventory snapshot (using the shared method)
  # 3. We filter to snapshots where available is between 1 and threshold
  # 4. .distinct removes duplicates (a product with 2 low-stock variants appears once)
  #
  def self.with_low_stock(shop)
    threshold = shop.low_stock_threshold
    latest_sql = InventorySnapshot.latest_per_variant(shop_id: shop.id).to_sql

    joins(:variants)
      .joins("INNER JOIN (#{latest_sql}) AS latest_snap ON latest_snap.variant_id = variants.id")
      .where('latest_snap.available > 0 AND latest_snap.available < ?', threshold)
      .distinct
  end

  # Returns products that have at least one variant with zero stock.
  def self.out_of_stock_only(shop)
    latest_sql = InventorySnapshot.latest_per_variant(shop_id: shop.id).to_sql

    joins(:variants)
      .joins("INNER JOIN (#{latest_sql}) AS latest_snap ON latest_snap.variant_id = variants.id")
      .where('latest_snap.available = 0')
      .distinct
  end

  # Searches products by title OR any variant's SKU (case-insensitive).
  #
  # sanitize_sql_like escapes special SQL characters (%, _) in the search term
  # so users can search for literal "100%" without it matching everything.
  #
  # ILIKE is PostgreSQL's case-insensitive version of LIKE.
  #
  def self.search_by_title_or_sku(query)
    return all if query.blank?

    term = "%#{sanitize_sql_like(query)}%"
    left_joins(:variants)
      .where('products.title ILIKE :q OR variants.sku ILIKE :q', q: term)
      .distinct
  end
end
