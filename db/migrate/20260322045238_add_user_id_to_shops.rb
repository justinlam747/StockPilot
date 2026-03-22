# frozen_string_literal: true

class AddUserIdToShops < ActiveRecord::Migration[7.2]
  def change
    add_reference :shops, :user, foreign_key: true, null: true
    add_index :shops, [:user_id, :shop_domain], unique: true
    # Deferred FK from users.active_shop_id → shops.id
    add_foreign_key :users, :shops, column: :active_shop_id
  end
end
