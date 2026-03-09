class CreatePurchaseOrderLineItems < ActiveRecord::Migration[7.2]
  def change
    create_table :purchase_order_line_items do |t|
      t.references :purchase_order, null: false, foreign_key: { on_delete: :cascade }
      t.references :variant,        null: false, foreign_key: true
      t.string  :sku
      t.string  :title
      t.integer :qty_ordered,  null: false, default: 0
      t.integer :qty_received, null: false, default: 0
      t.decimal :unit_price, precision: 10, scale: 2

      t.timestamps
    end
  end
end
