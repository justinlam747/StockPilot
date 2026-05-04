# frozen_string_literal: true

module Agents
  # Reviews current inventory risk and records operator-facing recommendations.
  class InventoryMonitor
    def initialize(shop, summary_client: SummaryClient.new(shop))
      @shop = shop
      @summary_client = summary_client
    end

    def execute(run)
      @run = run
      @logger = RunLogger.new(run)

      log_start!
      log_correction_note!
      result = generate_recommendations
      persist_recommendations!(result.recommendations)
      summary = write_summary!(result)
      complete_run!(summary, result)

      summary
    end

    private

    def generate_recommendations
      @logger.log_progress!(
        phase: 'Evaluating stock risk',
        percent: 35,
        content: 'Generating inventory recommendations.'
      )
      result = RecommendationEngine.call(shop: @shop, goal: @run.goal, correction: correction_note)
      log_correction_rules!(result)
      log_recommendation_counts!(result)

      @logger.log_progress!(
        phase: 'Drafting proposed actions',
        percent: 65,
        content: "Persisting #{result.recommendations.size} recommendation(s)."
      )
      result
    end

    def write_summary!(result)
      summary_context = build_summary_context(result)
      @logger.log_progress!(
        phase: 'Writing run summary',
        percent: 85,
        content: 'Preparing operator summary.'
      )
      summary = @summary_client.generate(summary_context)
      @logger.log_message!(
        content: summary,
        event_type: 'summary',
        metadata: { provider: @summary_client.provider_name }
      )
      summary
    end

    def complete_run!(summary, result)
      summary_context = build_summary_context(result)
      @run.update!(
        status: 'completed',
        current_phase: 'Completed',
        progress_percent: 100,
        finished_at: Time.current,
        turns_count: correction_note.present? ? 2 : 1,
        summary: summary,
        result_payload: summary_context['result_payload']
      )
      @logger.log_progress!(phase: 'Completed', percent: 100, content: 'Agent run completed.')
    end

    def log_start!
      @logger.log_progress!(
        phase: 'Gathering inventory context',
        percent: 10,
        content: "Starting inventory monitor for #{@shop.shop_domain}."
      )
      @logger.log_message!(content: @run.goal, role: 'user', event_type: 'goal') if @run.goal.present?
    end

    def correction_note
      @correction_note ||= @run.input_payload['correction'].presence
    end

    def log_correction_note!
      return if correction_note.blank?

      @logger.log_message!(
        content: correction_note,
        role: 'user',
        event_type: 'correction',
        metadata: { parent_run_id: @run.parent_run_id }
      )
    end

    def log_correction_rules!(result)
      return if result.correction_rules.empty?

      @logger.log_message!(
        content: "Applied correction rules: #{result.correction_rules.join(', ').tr('_', ' ')}.",
        role: 'system',
        event_type: 'correction_applied',
        metadata: { rules: result.correction_rules, parent_run_id: @run.parent_run_id }
      )
    end

    def log_recommendation_counts!(result)
      @logger.log_message!(
        content: "#{result.counts['low_stock']} low-stock and #{result.counts['out_of_stock']} " \
                 "out-of-stock SKU(s) identified; #{result.recommendations.size} recommendation(s) generated.",
        metadata: { counts: result.counts }
      )
    end

    def persist_recommendations!(recommendations)
      recommendations.each do |recommendation|
        @logger.propose_action!(
          action_type: recommendation.fetch(:action_type),
          title: recommendation[:title],
          details: recommendation[:details],
          payload: recommendation.fetch(:payload)
        )
      end
    end

    def build_summary_context(result)
      result_payload = result.result_payload.merge(
        'previous_summary' => @run.parent_run&.summary
      ).compact

      result_payload.merge(
        'previous_summary' => @run.parent_run&.summary,
        'result_payload' => result_payload
      ).compact
    end
  end
end
