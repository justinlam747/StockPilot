# frozen_string_literal: true

# Processes GDPR customers/redact webhook (no customer PII stored).
class GdprCustomerRedactJob < ApplicationJob
  queue_as :default

  def perform(shop_id, customer_id)
    shop = Shop.find_by(id: shop_id)
    return log_skip(shop_id) unless shop

    AuditLog.record(
      action: 'gdpr_customer_redact', shop: shop,
      metadata: { customer_id: customer_id, status: 'completed' }
    )
    log_no_pii(customer_id, shop_id)
  end

  private

  def log_skip(shop_id)
    Rails.logger.info("[GDPR] Customer redact for unknown shop #{shop_id} — skipping")
  end

  def log_no_pii(customer_id, shop_id)
    Rails.logger.info("[GDPR] Customer #{customer_id} redact for shop #{shop_id} — no PII stored")
  end
end
