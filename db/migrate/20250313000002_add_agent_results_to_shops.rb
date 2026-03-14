class AddAgentResultsToShops < ActiveRecord::Migration[7.2]
  def change
    add_column :shops, :last_agent_run_at, :datetime
    add_column :shops, :last_agent_results, :jsonb, default: {}
  end
end
