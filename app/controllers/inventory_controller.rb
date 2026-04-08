# frozen_string_literal: true

# Displays paginated inventory with filtering by stock status and search.
#
# This controller handles HTTP concerns only:
#   - Read URL parameters (filter, search, sort, page)
#   - Call model scopes to get the right data
#   - Paginate and render
#
# The actual query logic lives in the models (Product, InventorySnapshot)
# where Rails developers expect to find it.
#
class InventoryController < ApplicationController
  before_action :require_shop!

  def index
    load_inventory_stats
    @products = find_filtered_products
    attach_current_stock_to_variants(@products)

    return unless request.headers['HX-Request']

    partial = params[:view] == 'table' ? 'table' : 'grid'
    render partial: partial, locals: { products: @products }
  end

  def show
    @product = Product.includes(variants: %i[inventory_snapshots supplier]).find(params[:id])
    @snapshot_data = load_chart_data_for_product(@product)
  end

  private

  # Builds the product list by chaining model scopes.
  # Each scope is defined on the Product model — look there for the SQL.
  def find_filtered_products
    scope = Product.includes(:variants)
    scope = apply_stock_filter(scope)
    scope = apply_search(scope)
    scope = apply_sort(scope)
    scope.page(params[:page]).per(24)
  end

  def apply_stock_filter(scope)
    case params[:filter]
    when 'low_stock'    then scope.with_low_stock(current_shop)
    when 'out_of_stock' then scope.out_of_stock_only(current_shop)
    else scope
    end
  end

  def apply_search(scope)
    return scope unless params[:q].present?

    scope.search_by_title_or_sku(params[:q])
  end

  def apply_sort(scope)
    case params[:sort]
    when 'title_desc' then scope.order(title: :desc)
    when 'newest'     then scope.order(created_at: :desc)
    when 'vendor'     then scope.order(:vendor, :title)
    else scope.order(:title)
    end
  end

  def load_inventory_stats
    stats = shop_cache.inventory_stats
    @total_variants = Variant.where(shop_id: current_shop.id).count
    @low_stock = stats[:low_stock]
    @out_of_stock = stats[:out_of_stock]
    @healthy_products = [stats[:total_products] - @low_stock - @out_of_stock, 0].max
  end

  # Sets variant.current_stock on each variant so the view can display
  # stock levels without loading the full snapshot history.
  #
  # Uses the shared InventorySnapshot.latest_per_variant method.
  # index_by turns the array into a hash: { variant_id => snapshot }
  # so we can look up each variant's stock in O(1) time.
  #
  def attach_current_stock_to_variants(products)
    all_variants = products.flat_map { |p| p.variants.to_a }
    return if all_variants.empty?

    variant_ids = all_variants.map(&:id)
    stock_map = InventorySnapshot.latest_per_variant(
      shop_id: current_shop.id, variant_ids: variant_ids
    ).index_by(&:variant_id)

    all_variants.each { |v| v.current_stock = stock_map[v.id]&.available || 0 }
  end

  # Loads 14 days of chart data using InventorySnapshot.daily_totals.
  def load_chart_data_for_product(product)
    variant_ids = product.variants.map(&:id)
    return {} if variant_ids.empty?

    InventorySnapshot.daily_totals(variant_ids: variant_ids, days: 14)
  end
end
