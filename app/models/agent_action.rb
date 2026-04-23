# frozen_string_literal: true

# Proposed or resolved action captured during an agent run.
class AgentAction < ApplicationRecord
  STATUSES = %w[proposed approved rejected applied failed].freeze

  belongs_to :agent_run, inverse_of: :actions

  before_validation :normalize_payload

  validates :action_type, presence: true
  validates :status, presence: true, inclusion: { in: STATUSES }

  private

  def normalize_payload
    self.payload ||= {}
  end
end
