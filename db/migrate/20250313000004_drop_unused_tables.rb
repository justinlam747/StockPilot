class DropUnusedTables < ActiveRecord::Migration[7.2]
  def up
    drop_table :customers, if_exists: true
    drop_table :webhook_endpoints, if_exists: true
    drop_table :weekly_reports, if_exists: true
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
