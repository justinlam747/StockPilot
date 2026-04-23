# frozen_string_literal: true

class CreateAgentRuntimeTables < ActiveRecord::Migration[7.2]
  def change
    create_table :agent_runs do |t|
      t.references :shop, null: false, foreign_key: { on_delete: :cascade }
      t.references :parent_run, foreign_key: { to_table: :agent_runs, on_delete: :nullify }
      t.string :agent_kind, null: false, default: 'inventory_monitor'
      t.string :status, null: false, default: 'queued'
      t.string :trigger_source, null: false, default: 'manual'
      t.text :goal
      t.integer :progress_percent, null: false, default: 0
      t.string :current_phase
      t.integer :turns_count, null: false, default: 0
      t.datetime :started_at
      t.datetime :finished_at
      t.text :error_message
      t.text :summary
      t.jsonb :input_payload, default: {}, null: false
      t.jsonb :result_payload, default: {}, null: false
      t.jsonb :metadata, default: {}, null: false
      t.timestamps
    end

    add_index :agent_runs, %i[shop_id status created_at]
    add_index :agent_runs, %i[shop_id created_at]

    create_table :agent_events do |t|
      t.references :agent_run, null: false, foreign_key: { on_delete: :cascade }
      t.string :event_type, null: false
      t.string :role
      t.integer :sequence, null: false
      t.text :content
      t.jsonb :metadata, default: {}, null: false
      t.timestamps
    end

    add_index :agent_events, %i[agent_run_id sequence], unique: true
    add_index :agent_events, %i[agent_run_id created_at]

    create_table :agent_actions do |t|
      t.references :agent_run, null: false, foreign_key: { on_delete: :cascade }
      t.string :action_type, null: false
      t.string :status, null: false, default: 'proposed'
      t.string :title
      t.text :details
      t.jsonb :payload, default: {}, null: false
      t.text :resolution_note
      t.timestamps
    end

    add_index :agent_actions, %i[agent_run_id status created_at]
    add_index :agent_actions, %i[agent_run_id created_at]
  end
end
