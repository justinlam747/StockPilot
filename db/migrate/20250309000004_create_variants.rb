# frozen_string_literal: true

class CreateVariants < ActiveRecord::Migration[7.2]
  def change
    create_table :variants do |t|
      t.references :shop,     null: false, foreign_key: { on_delete: :cascade }
      t.references :product,  null: false, foreign_key: { on_delete: :cascade }
      t.references :supplier, foreign_key: { on_delete: :nullify }
      t.bigint  :shopify_variant_id, null: false
      t.bigint  :shopify_inventory_item_id
      t.string  :sku
      t.string  :title
      t.decimal :price, precision: 10, scale: 2
      t.integer :low_stock_threshold

      t.timestamps
    end

    add_index :variants, %i[shop_id shopify_variant_id], unique: true
    add_index :variants, %i[shop_id sku]
  end
end
