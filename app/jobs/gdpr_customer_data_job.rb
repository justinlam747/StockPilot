# frozen_string_literal: true

class GdprCustomerDataJob < ApplicationJob
  queue_as :default

  def perform(shop_id, customer_id)
    shop = Shop.find_by(id: shop_id)
    unless shop
      Rails.logger.info("[GDPR] Customer data request for unknown shop #{shop_id} — skipping")
      return
    end

    AuditLog.record(
      action: 'gdpr_customer_data_export',
      shop: shop,
      metadata: { customer_id: customer_id, status: 'completed' }
    )

    # This app does not store customer PII directly. All inventory data is
    # product-level, not customer-level. Order data is fetched on-demand from
    # Shopify's API and not persisted. No customer data to export.
    Rails.logger.info("[GDPR] Customer #{customer_id} data request for shop #{shop_id} — no customer PII stored in this app")
  end
end
