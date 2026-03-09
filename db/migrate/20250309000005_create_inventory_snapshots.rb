class CreateInventorySnapshots < ActiveRecord::Migration[7.2]
  def change
    create_table :inventory_snapshots do |t|
      t.references :shop,    null: false, foreign_key: { on_delete: :cascade }
      t.references :variant, null: false, foreign_key: { on_delete: :cascade }
      t.integer :available,  null: false, default: 0
      t.integer :on_hand,    null: false, default: 0
      t.integer :committed,  null: false, default: 0
      t.integer :incoming,   null: false, default: 0
      t.timestamp :snapshotted_at, null: false, default: -> { "NOW()" }

      t.timestamp :created_at, null: false, default: -> { "NOW()" }
    end

    add_index :inventory_snapshots, [:variant_id, :snapshotted_at],
              order: { snapshotted_at: :desc },
              name: "idx_snapshots_variant_time"
    add_index :inventory_snapshots, [:shop_id, :snapshotted_at],
              name: "idx_snapshots_shop_time"
  end
end
