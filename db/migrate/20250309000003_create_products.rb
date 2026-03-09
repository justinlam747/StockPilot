class CreateProducts < ActiveRecord::Migration[7.2]
  def change
    create_table :products do |t|
      t.references :shop, null: false, foreign_key: { on_delete: :cascade }
      t.bigint  :shopify_product_id, null: false
      t.string  :title
      t.string  :product_type
      t.string  :vendor
      t.string  :status
      t.timestamp :deleted_at
      t.timestamp :synced_at

      t.timestamps
    end

    add_index :products, [:shop_id, :shopify_product_id], unique: true
    add_index :products, [:shop_id, :status]
  end
end
