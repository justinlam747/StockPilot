# frozen_string_literal: true

module Agents
  # Writes timeline events, progress updates, and proposed actions for a run.
  class RunLogger
    def initialize(run)
      @run = run
    end

    def log_progress!(phase:, percent:, content: nil, metadata: {})
      @run.update!(
        current_phase: phase,
        progress_percent: percent,
        started_at: @run.started_at || Time.current
      )

      log_event!(
        event_type: 'progress',
        role: 'system',
        content: content || phase,
        metadata: metadata.merge('phase' => phase, 'progress_percent' => percent)
      )
    end

    def log_message!(content:, role: 'assistant', event_type: 'message', metadata: {})
      log_event!(
        event_type: event_type,
        role: role,
        content: content,
        metadata: metadata
      )
    end

    def propose_action!(action_type:, title:, details:, payload:, status: 'proposed')
      @run.actions.create!(
        action_type: action_type,
        status: status,
        title: title,
        details: details,
        payload: payload
      )
    end

    private

    def log_event!(event_type:, role:, content:, metadata:)
      @run.with_lock do
        @run.events.create!(
          event_type: event_type,
          role: role,
          content: content,
          sequence: @run.events.maximum(:sequence).to_i + 1,
          metadata: metadata
        )
      end
    end
  end
end
