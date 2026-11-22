class InventorySyncJob < ActiveJob::Base
  queue_as :shopify_inventory
  discard_on ActiveRecord::RecordNotFound, Shop::ReauthorizationRequired

  def perform(shop_id, installation_id)
    shop = Shop.active.find_by!(id: shop_id, installation_id: installation_id)
    started_at = Time.current
    inventory = Shopify::InventoryFetcher.new(shop).enum_for(:each_variant).to_a
    shop.with_lock do
      return if shop.uninstalled_at? || shop.installation_id != installation_id
      return if shop.synced_at && shop.synced_at > started_at
      inventory.each { |variant, totals| persist(shop, variant, totals, started_at) }
      seen = shop.inventory_snapshots.where(snapshotted_at: started_at).select(:variant_id)
      shop.variants.where(deleted_at: nil).where.not(shopify_variant_id: nil).where.not(id: seen)
        .update_all(deleted_at: started_at)
      shop.update!(synced_at: started_at)
    end
  end

  private

  def persist(shop, data, quantities, at)
    source = data.fetch('product')
    product = shop.products.find_or_initialize_by(shopify_product_id: source.fetch('legacyResourceId'))
    return if product.deleted_at && product.deleted_at > at
    product.update!(title: source.fetch('title'), deleted_at: nil)
    variant = shop.variants.find_or_initialize_by(shopify_variant_id: data.fetch('legacyResourceId'))
    variant.update!(product: product, title: data.fetch('title'), sku: data['sku'], deleted_at: nil)
    shop.inventory_snapshots.create!(quantities.merge(variant: variant, snapshotted_at: at, created_at: at))
  end
end
