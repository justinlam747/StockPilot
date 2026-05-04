# frozen_string_literal: true

# Proposed or resolved action captured during an agent run.
class AgentAction < ApplicationRecord
  STATUSES = %w[proposed accepted rejected edited applied failed approved].freeze
  RESOLVABLE_STATUSES = %w[proposed edited accepted].freeze

  belongs_to :agent_run, inverse_of: :actions

  before_validation :normalize_payload

  validates :action_type, presence: true
  validates :status, presence: true, inclusion: { in: STATUSES }

  def resolvable?
    RESOLVABLE_STATUSES.include?(status)
  end

  def applied_record_path
    purchase_order_id = payload['applied_purchase_order_id']
    return if purchase_order_id.blank?

    Rails.application.routes.url_helpers.purchase_order_path(purchase_order_id)
  end

  private

  def normalize_payload
    self.payload ||= {}
  end
end
