# frozen_string_literal: true

# Tier 3: Live Agent Stream — persists agent execution history for streaming,
# replay, and audit. Each run captures steps in real-time via Redis pub/sub
# and stores them for reconnection resilience.
class CreateAgentRuns < ActiveRecord::Migration[7.2]
  def change
    create_table :agent_runs do |t|
      t.bigint :shop_id, null: false
      t.string :status, null: false, default: 'pending'
      t.string :provider
      t.string :model
      t.integer :turns, default: 0
      t.jsonb :results, default: {}
      t.jsonb :steps, default: []
      t.datetime :started_at
      t.datetime :completed_at
      t.text :error_message
      t.timestamps

      t.index %i[shop_id created_at], order: { created_at: :desc }, name: 'idx_agent_runs_shop_created'
      t.index %i[shop_id status], name: 'idx_agent_runs_shop_status'
    end

    add_foreign_key :agent_runs, :shops, on_delete: :cascade
  end
end
