# frozen_string_literal: true

# Tracks a single AI agent execution — status, steps, and results.
# Supports real-time streaming via Redis pub/sub and reconnection via persisted steps.
class AgentRun < ApplicationRecord
  acts_as_tenant :shop

  belongs_to :shop

  STATUSES = %w[pending running completed failed cancelled].freeze

  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :provider, inclusion: { in: %w[anthropic openai google], allow_blank: true }

  scope :in_progress, -> { where(status: %w[pending running]) }
  scope :recent, -> { order(created_at: :desc) }

  def completed?
    status == 'completed'
  end

  def failed?
    status == 'failed'
  end

  def cancelled?
    status == 'cancelled'
  end

  def in_progress?
    %w[pending running].include?(status)
  end

  def duration_seconds
    return nil unless started_at && completed_at

    (completed_at - started_at).round(1)
  end
end
