# frozen_string_literal: true

# Executes a queued agent run and records failures on the run itself.
class AgentRunJob < ApplicationJob
  MAX_ATTEMPTS = 3

  queue_as :default

  discard_on ActiveRecord::RecordNotFound
  retry_on StandardError, wait: :polynomially_longer, attempts: MAX_ATTEMPTS

  def perform(agent_run_id)
    run = AgentRun.includes(:shop, :parent_run).find(agent_run_id)

    ActsAsTenant.with_tenant(run.shop) do
      return unless claim_run?(run)

      Agents::InventoryMonitor.new(run.shop).execute(run)
    end
  rescue StandardError => e
    raise e if executions < MAX_ATTEMPTS

    handle_failure(run, e) if run
  end

  private

  def claim_run?(run)
    run.with_lock do
      return false unless run.status == 'queued'

      run.update!(
        status: 'running',
        started_at: run.started_at || Time.current,
        current_phase: 'Booting agent'
      )
    end

    true
  end

  def handle_failure(run, error)
    run.update!(
      status: 'failed',
      finished_at: Time.current,
      current_phase: 'Failed',
      error_message: error.message
    )
    Agents::RunLogger.new(run).log_message!(
      content: "Run failed: #{error.message}",
      role: 'system',
      event_type: 'error',
      metadata: { error_class: error.class.name }
    )
    Rails.logger.error("[AgentRunJob] Run #{run.id} failed: #{error.class}: #{error.message}")
  rescue StandardError => e
    Rails.logger.error("[AgentRunJob] Failed to record error for run #{run.id}: #{e.message}")
  end
end
