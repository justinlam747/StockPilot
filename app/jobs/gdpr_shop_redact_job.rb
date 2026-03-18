# frozen_string_literal: true

# Deletes all shop data in response to a GDPR shop/redact webhook.
class GdprShopRedactJob < ApplicationJob
  queue_as :default

  def perform(shop_id)
    shop = Shop.find_by(id: shop_id)
    return unless shop

    delete_tenant_data(shop)
    log_redaction(shop)
    shop.destroy!
  end

  private

  def delete_tenant_data(shop)
    ActsAsTenant.with_tenant(shop) do
      PurchaseOrderLineItem.delete_all
      PurchaseOrder.delete_all
      Alert.delete_all
      InventorySnapshot.delete_all
      Variant.delete_all
      Product.delete_all
      Supplier.delete_all
    end
  end

  def log_redaction(shop)
    AuditLog.record(
      action: 'gdpr_shop_redacted',
      metadata: { shop_id: shop.id, shop_domain: shop.shop_domain }
    )
    Rails.logger.info("[GDPR] Shop #{shop.id} (#{shop.shop_domain}) fully redacted")
  end
end
