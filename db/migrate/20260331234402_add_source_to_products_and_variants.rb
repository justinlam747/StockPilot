# frozen_string_literal: true

class AddSourceToProductsAndVariants < ActiveRecord::Migration[7.2]
  def change
    add_column :products, :source, :string, default: 'shopify'
    add_column :variants, :source, :string, default: 'shopify'
    change_column_null :products, :shopify_product_id, true
    change_column_null :variants, :shopify_variant_id, true
  end
end
