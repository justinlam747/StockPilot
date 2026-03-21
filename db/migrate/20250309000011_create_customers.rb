# frozen_string_literal: true

class CreateCustomers < ActiveRecord::Migration[7.2]
  def change
    create_table :customers do |t|
      t.references :shop, null: false, foreign_key: { on_delete: :cascade }
      t.bigint  :shopify_customer_id, null: false
      t.string  :email
      t.string  :first_name
      t.string  :last_name
      t.integer :total_orders,  default: 0
      t.decimal :total_spent,   precision: 12, scale: 2, default: 0
      t.decimal :avg_order_value, precision: 10, scale: 2
      t.decimal :avg_days_between_orders, precision: 6, scale: 1
      t.timestamp :first_order_at
      t.timestamp :last_order_at
      t.jsonb :top_product_types, default: []

      t.timestamps
    end

    add_index :customers, %i[shop_id shopify_customer_id], unique: true
  end
end
