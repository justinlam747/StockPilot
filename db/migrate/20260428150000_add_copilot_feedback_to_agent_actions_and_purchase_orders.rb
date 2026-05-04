# frozen_string_literal: true

class AddCopilotFeedbackToAgentActionsAndPurchaseOrders < ActiveRecord::Migration[7.2]
  def change
    add_column :agent_actions, :feedback_note, :text
    add_column :agent_actions, :resolved_at, :datetime
    add_column :agent_actions, :resolved_by, :string

    add_column :purchase_orders, :source, :string
    add_reference :purchase_orders, :source_agent_run, foreign_key: { to_table: :agent_runs, on_delete: :nullify }
    add_reference :purchase_orders, :source_agent_action, foreign_key: { to_table: :agent_actions, on_delete: :nullify }
  end
end
