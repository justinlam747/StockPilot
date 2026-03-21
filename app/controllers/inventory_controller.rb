# frozen_string_literal: true

# Displays paginated inventory with filtering by stock status and search.
class InventoryController < ApplicationController
  def index
    @products = Product.includes(variants: :inventory_snapshots)
    @products = apply_filter(@products)
    @products = apply_search(@products)
    @products = @products.page(params[:page]).per(25)

    return unless request.headers['HX-Request']

    partial = params[:view] == 'table' ? 'table' : 'grid'
    render partial: partial, locals: { products: @products }
  end

  def show
    @product = Product.includes(variants: :inventory_snapshots).find(params[:id])
  end

  private

  def apply_filter(scope)
    case params[:filter]
    when 'low_stock' then filter_low_stock(scope)
    when 'out_of_stock' then filter_out_of_stock(scope)
    else scope
    end
  end

  def filter_low_stock(scope)
    threshold = current_shop&.low_stock_threshold || 10
    join = Arel.sql("INNER JOIN (#{latest_snapshot_sql}) AS latest_snap ON latest_snap.variant_id = variants.id")
    scope.joins(:variants)
         .joins(join)
         .where('latest_snap.available > 0 AND latest_snap.available <= ?', threshold)
         .distinct
  end

  def filter_out_of_stock(scope)
    join = Arel.sql("INNER JOIN (#{latest_snapshot_sql}) AS latest_snap ON latest_snap.variant_id = variants.id")
    scope.joins(:variants)
         .joins(join)
         .where('latest_snap.available = 0')
         .distinct
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

    scope.where('products.title ILIKE ?', "%#{params[:q]}%")
  end
end
