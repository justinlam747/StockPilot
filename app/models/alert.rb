class Alert < ApplicationRecord
  acts_as_tenant :shop

  belongs_to :variant

  def severity
    metadata&.dig("severity") || (alert_type == "out_of_stock" ? "critical" : "warning")
  end

  def message
    metadata&.dig("message") || "#{alert_type.titleize} — #{variant&.product&.title} (#{variant&.sku})"
  end

  def dismissed?
    status == "dismissed"
  end
end
