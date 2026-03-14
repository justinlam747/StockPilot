class InventoryController < ApplicationController
  def index
    @products = Product.includes(:variants)
    @products = apply_filter(@products)
    @products = apply_search(@products)
    @products = @products.page(params[:page]).per(25)

    if request.headers["HX-Request"]
      render partial: "table", locals: { products: @products }
    end
  end

  def show
    @product = Product.includes(:variants).find(params[:id])
  end

  private

  def apply_filter(scope)
    case params[:filter]
    when "low_stock"
      latest = latest_snapshot_subquery
      scope.joins(:variants)
           .joins("INNER JOIN (#{latest}) latest ON latest.variant_id = variants.id")
           .where("latest.available > 0 AND latest.available <= COALESCE(variants.low_stock_threshold, ?)", current_shop.low_stock_threshold)
           .distinct
    when "out_of_stock"
      latest = latest_snapshot_subquery
      scope.joins(:variants)
           .joins("INNER JOIN (#{latest}) latest ON latest.variant_id = variants.id")
           .where("latest.available <= 0")
           .distinct
    else
      scope
    end
  end

  def latest_snapshot_subquery
    InventorySnapshot
      .select("DISTINCT ON (variant_id) variant_id, available")
      .where(shop_id: current_shop.id)
      .order("variant_id, created_at DESC")
      .to_sql
  end

  def apply_search(scope)
    return scope unless params[:q].present?
    scope.where("products.title ILIKE ?", "%#{params[:q]}%")
  end
end
