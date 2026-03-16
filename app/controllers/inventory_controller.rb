class InventoryController < ApplicationController
  def index
    @filter = params[:filter] || "all"
    @products = Product.includes(variants: :inventory_snapshots)
    @products = apply_search(@products)
    @products = @products.order(:title).page(params[:page]).per(25)

    if request.headers["HX-Request"]
      render partial: "table", locals: { products: @products, filter: @filter }
    end
  end

  def show
    @product = Product.includes(variants: :inventory_snapshots).find(params[:id])
  end

  private

  def apply_search(scope)
    return scope unless params[:q].present?
    scope.where("products.title ILIKE ?", "%#{params[:q]}%")
  end
end
