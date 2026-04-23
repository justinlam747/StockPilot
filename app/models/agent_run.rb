# frozen_string_literal: true

# A persisted execution record for an inventory-monitoring agent run.
class AgentRun < ApplicationRecord
  acts_as_tenant :shop

  belongs_to :shop
  AGENT_KINDS = %w[inventory_monitor].freeze
  STATUSES = %w[queued running awaiting_review paused completed failed cancelled timed_out].freeze
  TRIGGER_SOURCES = %w[manual scheduled webhook retry system].freeze

  belongs_to :parent_run, class_name: 'AgentRun', optional: true, inverse_of: :child_runs
  has_many :child_runs, class_name: 'AgentRun', foreign_key: :parent_run_id, inverse_of: :parent_run,
                        dependent: :nullify
  has_many :events, -> { order(:sequence, :created_at) }, class_name: 'AgentEvent', dependent: :destroy,
                                                          inverse_of: :agent_run
  has_many :actions, -> { order(:created_at) }, class_name: 'AgentAction', dependent: :destroy,
                                                inverse_of: :agent_run

  validates :agent_kind, presence: true, inclusion: { in: AGENT_KINDS }
  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :trigger_source, presence: true, inclusion: { in: TRIGGER_SOURCES }
  validates :progress_percent, numericality: {
    only_integer: true,
    greater_than_or_equal_to: 0,
    less_than_or_equal_to: 100
  }
  validates :turns_count, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  validate :finished_at_not_before_started_at
  validate :parent_run_must_belong_to_same_shop

  scope :recent_first, -> { order(created_at: :desc) }
  scope :active, -> { where(status: %w[queued running paused awaiting_review]) }

  before_validation :normalize_payloads

  private

  def normalize_payloads
    self.input_payload ||= {}
    self.result_payload ||= {}
    self.metadata ||= {}
  end

  def finished_at_not_before_started_at
    return if started_at.blank? || finished_at.blank?
    return unless finished_at < started_at

    errors.add(:finished_at, 'must be on or after started_at')
  end

  def parent_run_must_belong_to_same_shop
    return if parent_run.blank? || shop_id.blank?
    return if parent_run.shop_id == shop_id

    errors.add(:parent_run, 'must belong to the same shop')
  end
end
