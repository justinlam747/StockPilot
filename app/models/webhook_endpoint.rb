class WebhookEndpoint < ApplicationRecord
  acts_as_tenant :shop

  scope :active, -> { where(is_active: true) }
end
