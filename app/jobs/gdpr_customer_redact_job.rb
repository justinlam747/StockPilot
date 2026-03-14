class GdprCustomerRedactJob < ApplicationJob
  queue_as :default

  def perform(shop_id, customer_id)
    Rails.logger.info("[GDPR] Customer #{customer_id} redact request for shop #{shop_id} — no customer data stored")
  end
end
