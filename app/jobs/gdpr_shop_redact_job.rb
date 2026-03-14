class GdprShopRedactJob < ApplicationJob
  queue_as :default

  def perform(shop_id)
    shop = Shop.find_by(id: shop_id)
    return unless shop

    ActsAsTenant.with_tenant(shop) do
      PurchaseOrderLineItem.delete_all
      PurchaseOrder.delete_all
      Alert.delete_all
      InventorySnapshot.delete_all
      Variant.delete_all
      Product.delete_all
      Supplier.delete_all
    end

    shop.destroy!
    Rails.logger.info("[GDPR] Shop #{shop_id} fully redacted")
  end
end
