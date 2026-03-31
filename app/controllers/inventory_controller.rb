# frozen_string_literal: true

# Displays paginated inventory with filtering by stock status and search.
class InventoryController < ApplicationController
  before_action :require_shop!

  def index
    load_inventory_stats
    @products = build_product_scope
    preload_current_stock(@products)

    return unless request.headers['HX-Request']

    partial = params[:view] == 'table' ? 'table' : 'grid'
    render partial: partial, locals: { products: @products }
  end

  def show
    @product = Product.includes(variants: %i[inventory_snapshots supplier]).find(params[:id])
    @snapshot_data = load_snapshot_history(@product)
  end

  private

  def build_product_scope
    scope = Product.includes(:variants)
    scope = apply_filter(scope)
    scope = apply_search(scope)
    scope = apply_sort(scope)
    scope.page(params[:page]).per(24)
  end

  def apply_filter(scope)
    case params[:filter]
    when 'low_stock' then filter_low_stock(scope)
    when 'out_of_stock' then filter_out_of_stock(scope)
    else scope
    end
  end

  def filter_low_stock(scope)
    threshold = current_shop&.low_stock_threshold || 10
    with_latest_snapshot(scope).where('latest_snap.available > 0 AND latest_snap.available <= ?', threshold)
  end

  def filter_out_of_stock(scope)
    with_latest_snapshot(scope).where('latest_snap.available = 0')
  end

  def with_latest_snapshot(scope)
    join = Arel.sql("INNER JOIN (#{latest_snapshot_sql}) AS latest_snap ON latest_snap.variant_id = variants.id")
    scope.joins(:variants).joins(join).distinct
  end

  def latest_snapshot_sql
    InventorySnapshot
      .select('DISTINCT ON (variant_id) variant_id, available')
      .where(shop_id: current_shop&.id)
      .order('variant_id, created_at DESC')
      .to_sql
  end

  def apply_search(scope)
    return scope unless params[:q].present?

    term = "%#{ActiveRecord::Base.sanitize_sql_like(params[:q])}%"
    scope.left_joins(:variants)
         .where('products.title ILIKE :q OR variants.sku ILIKE :q', q: term)
         .distinct
  end

  def apply_sort(scope)
    case params[:sort]
    when 'title_desc' then scope.order(title: :desc)
    when 'newest' then scope.order(created_at: :desc)
    when 'vendor' then scope.order(:vendor, :title)
    else scope.order(:title)
    end
  end

  def load_snapshot_history(product)
    variant_ids = product.variants.map(&:id)
    return {} if variant_ids.empty?

    build_date_map(fetch_daily_snapshots(variant_ids))
  end

  def fetch_daily_snapshots(variant_ids)
    InventorySnapshot.where(variant_id: variant_ids)
                     .where('created_at >= ?', 14.days.ago)
                     .select('DATE(created_at) AS snap_date, SUM(available) AS total_available')
                     .group('DATE(created_at)')
                     .order('snap_date')
  end

  def build_date_map(snapshots)
    data = {}
    (13.days.ago.to_date..Date.current).each { |d| data[d] = 0 }
    snapshots.each { |s| data[s.snap_date.to_date] = s.total_available.to_i }
    data
  end

  def load_inventory_stats
    stats = shop_cache.inventory_stats
    @total_variants = Variant.where(shop_id: current_shop.id).count
    @low_stock = stats[:low_stock]
    @out_of_stock = stats[:out_of_stock]
    @healthy_products = [stats[:total_products] - @low_stock - @out_of_stock, 0].max
  end

  # Loads only the latest snapshot per variant in a single DISTINCT ON query,
  # then sets variant.current_stock to avoid loading full snapshot history.
  def preload_current_stock(products)
    all_variants = products.flat_map { |p| p.variants.to_a }
    return if all_variants.empty?

    stock_map = latest_stock_for(all_variants.map(&:id))
    all_variants.each { |v| v.current_stock = stock_map[v.id]&.available || 0 }
  end

  def latest_stock_for(variant_ids)
    InventorySnapshot
      .select('DISTINCT ON (variant_id) variant_id, available')
      .where(variant_id: variant_ids, shop_id: current_shop.id)
      .order('variant_id, created_at DESC')
      .index_by(&:variant_id)
  end
end
