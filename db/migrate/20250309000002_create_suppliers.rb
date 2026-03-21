# frozen_string_literal: true

class CreateSuppliers < ActiveRecord::Migration[7.2]
  def change
    create_table :suppliers do |t|
      t.references :shop, null: false, foreign_key: { on_delete: :cascade }
      t.string  :name, null: false
      t.string  :email
      t.string  :contact_name
      t.integer :lead_time_days, default: 7
      t.text    :notes

      t.timestamps
    end
  end
end
