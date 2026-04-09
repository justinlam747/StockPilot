class DropAgentColumnsFromShops < ActiveRecord::Migration[7.2]
  def change
    remove_column :shops, :last_agent_run_at, :datetime
    remove_column :shops, :last_agent_results, :jsonb, default: {}
  end
end
