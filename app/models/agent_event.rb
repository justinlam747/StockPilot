# frozen_string_literal: true

# Timeline event emitted while an agent run is progressing.
class AgentEvent < ApplicationRecord
  belongs_to :agent_run, inverse_of: :events

  before_validation :normalize_metadata

  validates :event_type, presence: true
  validates :sequence, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 },
                       uniqueness: { scope: :agent_run_id }

  private

  def normalize_metadata
    self.metadata ||= {}
  end
end
