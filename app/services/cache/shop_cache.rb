# frozen_string_literal: true

module Cache
  # Per-shop caching layer for products, suppliers, and inventory stats.
  #
  # CACHING STRATEGIES USED:
  #
  # 1. Write-through (products, suppliers):
  #    When we save a product/supplier, we immediately update the cache too.
  #    This keeps the cache fresh without waiting for it to expire.
  #
  # 2. Cache-aside with short TTL (inventory stats):
  #    We read from cache first. If it's expired (every 2 minutes),
  #    we query the database, save the result to cache, and return it.
  #    Short TTL because inventory changes frequently.
  #
  # 3. Lazy load (products/suppliers lists):
  #    We only query the database when someone actually asks for the data.
  #    The result is cached for 6-12 hours since these change less often.
  #
  class ShopCache
    PRODUCT_TTL = 6.hours
    SUPPLIER_TTL = 12.hours
    INVENTORY_TTL = 2.minutes

    def initialize(shop)
      @shop = shop
    end

    # --- Products (write-through + lazy load) ---

    def products_with_variants
      Rails.cache.fetch(key('products:all'), expires_in: PRODUCT_TTL) do
        Product.where(shop_id: @shop.id).includes(:variants).order(:title).to_a
      end
    end

    def product(product_id)
      Rails.cache.fetch(key("products:#{product_id}"), expires_in: PRODUCT_TTL) do
        Product.where(shop_id: @shop.id).includes(:variants).find(product_id)
      end
    end

    def write_product(product)
      Rails.cache.write(key("products:#{product.id}"), product, expires_in: PRODUCT_TTL)
      invalidate_product_list
    end

    def invalidate_product(product_id)
      Rails.cache.delete(key("products:#{product_id}"))
      invalidate_product_list
    end

    def invalidate_product_list
      Rails.cache.delete(key('products:all'))
    end

    # --- Suppliers (write-through) ---

    def suppliers
      Rails.cache.fetch(key('suppliers:all'), expires_in: SUPPLIER_TTL) do
        Supplier.where(shop_id: @shop.id).order(:name).to_a
      end
    end

    def supplier(supplier_id)
      Rails.cache.fetch(key("suppliers:#{supplier_id}"), expires_in: SUPPLIER_TTL) do
        Supplier.where(shop_id: @shop.id).find(supplier_id)
      end
    end

    def write_supplier(supplier)
      Rails.cache.write(key("suppliers:#{supplier.id}"), supplier, expires_in: SUPPLIER_TTL)
      invalidate_supplier_list
    end

    def invalidate_supplier(supplier_id)
      Rails.cache.delete(key("suppliers:#{supplier_id}"))
      invalidate_supplier_list
    end

    def invalidate_supplier_list
      Rails.cache.delete(key('suppliers:all'))
    end

    # --- Inventory (cache-aside, short TTL) ---
    # DB is source of truth. After reading from DB, backfill cache.

    def inventory_stats
      Rails.cache.fetch(key('inventory:stats'), expires_in: INVENTORY_TTL) do
        build_inventory_stats
      end
    end

    def warm_inventory_stats
      stats = build_inventory_stats
      Rails.cache.write(key('inventory:stats'), stats, expires_in: INVENTORY_TTL)
      stats
    end

    def invalidate_inventory
      Rails.cache.delete(key('inventory:stats'))
    end

    # --- Bulk invalidation ---

    def invalidate_all
      invalidate_product_list
      invalidate_supplier_list
      invalidate_inventory
    end

    private

    def key(suffix)
      "shop:#{@shop.id}:#{suffix}"
    end

    # Builds dashboard stats using a fast COUNT query instead of loading
    # all flagged variants. Much cheaper when we only need numbers.
    def build_inventory_stats
      counts = InventorySnapshot.count_by_stock_status(@shop)
      {
        total_products: Product.where(shop_id: @shop.id).active.count,
        low_stock: counts[:low_stock],
        out_of_stock: counts[:out_of_stock],
        pending_pos: PurchaseOrder.where(shop_id: @shop.id, status: 'draft').count
      }
    end
  end
end
