# frozen_string_literal: true

# Monitoring and operator controls for agent runs.
class AgentsController < ApplicationController
  before_action :require_shop!
  before_action :set_run, only: %i[show corrections]

  def index
    @runs = current_shop.agent_runs.includes(:parent_run, :child_runs, :actions, :events).recent_first.limit(25)
    @status_counts = current_shop.agent_runs.group(:status).count
    @has_active_runs = @runs.any? { |run| %w[queued running paused awaiting_review].include?(run.status) }
  end

  def show
    @events = @run.events
    @actions = @run.actions
    @child_runs = @run.child_runs.order(created_at: :desc)
  end

  def run
    run = Agents::Runner.run_for_shop(current_shop.id, goal: params[:goal].presence)
    AuditLog.record(
      action: 'agent_run_requested',
      shop: current_shop,
      request: request,
      metadata: { agent_run_id: run.id, goal: run.goal }
    )
    notice = if run.previously_new_record?
               'Agent run queued'
             else
               "Run ##{run.id} is already active for this shop."
             end
    redirect_to agent_path(run), notice: notice
  end

  def corrections
    correction = params[:correction].to_s.strip
    if correction.blank?
      redirect_to agent_path(@run), alert: 'Correction cannot be blank'
      return
    end

    child_run = Agents::Runner.run_for_shop(
      current_shop.id,
      goal: @run.goal,
      correction: correction,
      parent_run: @run
    )

    AuditLog.record(
      action: 'agent_correction_requested',
      shop: current_shop,
      request: request,
      metadata: { agent_run_id: child_run.id, parent_run_id: @run.id }
    )

    notice = if child_run.previously_new_record?
               'Correction queued'
             else
               "Run ##{child_run.id} is already active for this shop."
             end
    redirect_to agent_path(child_run), notice: notice
  end

  private

  def set_run
    @run = current_shop.agent_runs.includes(:parent_run, :child_runs, :events, :actions).find(params[:id])
  end
end
