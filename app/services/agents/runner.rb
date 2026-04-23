# frozen_string_literal: true

module Agents
  # Creates and enqueues agent runs for shops.
  class Runner
    LOCK_NAMESPACE = 31_337
    DEFAULT_GOAL = 'Review inventory risk, summarize urgent issues, and propose next actions.'

    class << self
      def run_all_shops(goal: nil)
        Shop.active.find_each.map do |shop|
          run_for_shop(shop.id, goal: goal, trigger_source: 'scheduled')
        end
      end

      def run_for_shop(shop_id, goal: nil, correction: nil, parent_run: nil, trigger_source: nil)
        shop = Shop.active.find(shop_id)
        parent = resolve_parent_run(parent_run, shop)
        effective_goal = goal.presence || DEFAULT_GOAL
        follow_up_run = parent.present? || correction.present?
        enqueued = false

        run = ActsAsTenant.with_tenant(shop) do
          AgentRun.transaction do
            acquire_enqueue_lock!(shop.id)

            existing_run = AgentRun.active.find_by(agent_kind: 'inventory_monitor') unless follow_up_run
            next existing_run if existing_run

            enqueued = true
            AgentRun.create!(
              shop: shop,
              parent_run: parent,
              goal: effective_goal,
              trigger_source: trigger_source.presence || inferred_trigger_source(parent, correction),
              status: 'queued',
              current_phase: 'Queued for execution',
              input_payload: build_input_payload(
                goal: effective_goal,
                correction: correction,
                parent_run: parent
              )
            )
          end
        end

        AgentRunJob.perform_later(run.id) if enqueued
        run
      end

      private

      def acquire_enqueue_lock!(shop_id)
        ActiveRecord::Base.connection.execute(
          "SELECT pg_advisory_xact_lock(#{LOCK_NAMESPACE}, #{Integer(shop_id)})"
        )
      end

      def resolve_parent_run(parent_run, shop)
        return if parent_run.blank?
        return parent_run if parent_run.is_a?(AgentRun) && parent_run.shop_id == shop.id

        AgentRun.where(shop_id: shop.id).find(parent_run)
      end

      def inferred_trigger_source(parent_run, correction)
        return 'retry' if parent_run.present? || correction.present?

        'manual'
      end

      def build_input_payload(goal:, correction:, parent_run:)
        {
          'goal' => goal,
          'correction' => correction.presence,
          'parent_run_id' => parent_run&.id,
          'previous_summary' => parent_run&.summary
        }.compact
      end
    end
  end
end
