class SimplifySupplierRating < ActiveRecord::Migration[7.2]
  def change
    add_column :suppliers, :star_rating, :integer, default: 0
    add_column :suppliers, :rating_notes, :text
  end
end
