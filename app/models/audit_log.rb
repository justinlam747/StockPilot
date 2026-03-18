# frozen_string_literal: true

# Immutable record of security-relevant events for compliance.
class AuditLog < ApplicationRecord
  belongs_to :shop, optional: true

  validates :action, presence: true

  def readonly?
    persisted?
  end

  def self.record(action:, shop: nil, request: nil, metadata: {})
    create!(
      action: action,
      shop: shop,
      ip_address: request&.remote_ip,
      user_agent: request&.user_agent&.truncate(500),
      request_id: request&.request_id,
      metadata: metadata
    )
  end
end
