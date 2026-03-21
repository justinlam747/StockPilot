# frozen_string_literal: true

class AddPhoneToSuppliers < ActiveRecord::Migration[7.2]
  def change
    add_column :suppliers, :phone, :string
  end
end
