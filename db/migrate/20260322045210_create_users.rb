# frozen_string_literal: true

class CreateUsers < ActiveRecord::Migration[7.2]
  def change
    create_table :users do |t|
      t.string :clerk_user_id, null: false
      t.string :email, null: false
      t.string :name
      t.string :store_name
      t.string :store_category
      t.integer :onboarding_step, default: 1, null: false
      t.datetime :onboarding_completed_at
      t.bigint :active_shop_id
      t.datetime :deleted_at

      t.timestamps
    end

    add_index :users, :clerk_user_id, unique: true
    add_index :users, :email
    add_index :users, :deleted_at
    # FK for active_shop_id is deferred — added after shops migration
  end
end
