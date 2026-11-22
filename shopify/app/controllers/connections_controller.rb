class ConnectionsController < ActionController::Base
  protect_from_forgery with: :exception
  before_action :require_shop, only: %i[status inventory sync]
  before_action { response.headers['Cache-Control'] = 'no-store' }

  def show
    canonical = Rails.application.config.x.shopify_url
    if request.base_url != canonical
      return redirect_to "#{canonical}/connect", allow_other_host: true
    end
    @shop = current_shop
  end

  def callback
    auth = request.env.fetch('omniauth.auth')
    shop = Shop.install!(auth.uid, request.env.fetch('omniauth.strategy').access_token)
    reset_session
    session[:shop_id] = shop.id
    session[:installation] = shop.installation_id
    InventorySyncJob.perform_later(shop.id, shop.installation_id)
    redirect_to '/connect'
  rescue Shop::TokenError
    render plain: 'Shopify did not provide a renewable offline token. Reconnect the store.', status: :bad_gateway
  end

  def status
    render json: current_shop.as_json(only: %i[shop_domain installed_at synced_at reauthorization_required_at])
  end

  def inventory
    variants = current_shop.variants.joins(:product).includes(:product)
      .where(products: { shop_id: current_shop.id, deleted_at: nil })
      .where(variants: { deleted_at: nil }).where.not(shopify_variant_id: nil).where('variants.id > ?', params[:after].to_i)
      .order(:id).limit(101).to_a
    page = variants.first(100)
    snapshots = current_shop.inventory_snapshots.where(variant_id: page.map(&:id))
      .select('DISTINCT ON (variant_id) inventory_snapshots.*')
      .order(:variant_id, snapshotted_at: :desc, id: :desc).index_by(&:variant_id)
    rows = page.map do |variant|
      { product: variant.product.title, variant: variant.title, sku: variant.sku,
        shopify_variant_id: variant.shopify_variant_id,
        inventory: snapshots[variant.id]&.as_json(only: %i[available on_hand committed incoming snapshotted_at]) }
    end
    render json: { shop_domain: current_shop.shop_domain, items: rows, next_after: (page.last.id if variants.size > 100) }
  end

  def sync
    InventorySyncJob.perform_later(current_shop.id, current_shop.installation_id)
    redirect_to '/connect', status: :see_other
  end

  private

  def current_shop
    return unless session[:shop_id]
    return if session[:installation].blank?
    @current_shop ||= Shop.active.find_by(id: session[:shop_id], installation_id: session[:installation])
  end

  def require_shop
    head :unauthorized unless current_shop
  end
end
