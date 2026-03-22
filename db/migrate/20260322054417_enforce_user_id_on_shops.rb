# frozen_string_literal: true

class EnforceUserIdOnShops < ActiveRecord::Migration[7.2]
  def change
    change_column_null :shops, :user_id, false
  end
end
