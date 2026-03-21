# frozen_string_literal: true

# Processes GDPR customers/data_request webhook (no customer PII stored).
class GdprCustomerDataJob < ApplicationJob
  queue_as :default

  def perform(shop_id, customer_id)
    shop = Shop.find_by(id: shop_id)
    return log_unknown_shop('data request', shop_id) unless shop

    AuditLog.record(
      action: 'gdpr_customer_data_export', shop: shop,
      metadata: { customer_id: customer_id, status: 'completed' }
    )
    log_no_pii('data request', customer_id, shop_id)
  end

  private

  def log_unknown_shop(action, shop_id)
    Rails.logger.info("[GDPR] Customer #{action} for unknown shop #{shop_id} — skipping")
  end

  def log_no_pii(action, customer_id, shop_id)
    Rails.logger.info(
      "[GDPR] Customer #{customer_id} #{action} for shop #{shop_id} — no customer PII stored in this app"
    )
  end
end
