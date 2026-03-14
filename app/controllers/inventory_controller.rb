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
      scope.joins(:variants).where("variants.inventory_quantity > 0 AND variants.inventory_quantity <= 10").distinct
    when "out_of_stock"
      scope.joins(:variants).where(variants: { inventory_quantity: 0 }).distinct
    else
      scope
    end
  end

  def apply_search(scope)
    return scope unless params[:q].present?
    scope.where("products.title ILIKE ?", "%#{params[:q]}%")
  end
end
