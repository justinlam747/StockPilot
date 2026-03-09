class CreatePurchaseOrders < ActiveRecord::Migration[7.2]
  def change
    create_table :purchase_orders do |t|
      t.references :shop,     null: false, foreign_key: { on_delete: :cascade }
      t.references :supplier, null: false, foreign_key: true
      t.string  :po_number
      t.string  :status, null: false, default: "draft"
      t.text    :draft_body
      t.timestamp :sent_at

      t.timestamps
    end
  end
end
