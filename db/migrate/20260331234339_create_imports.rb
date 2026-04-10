# frozen_string_literal: true

class CreateImports < ActiveRecord::Migration[7.2]
  def change
    create_table :imports do |t|
      t.references :shop, null: false, foreign_key: { on_delete: :cascade }
      t.string :source, null: false # 'csv', 'paste', 'shopify'
      t.string :status, default: 'pending', null: false
      t.integer :total_rows, default: 0
      t.integer :imported_rows, default: 0
      t.integer :skipped_rows, default: 0
      t.jsonb :column_mapping, default: {}
      t.jsonb :errors_log, default: []
      t.text :raw_data
      t.datetime :completed_at
      t.timestamps
    end
    add_index :imports, %i[shop_id created_at]
  end
end
