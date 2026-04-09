# frozen_string_literal: true

# Enables pg_trgm extension and adds a GIN trigram index on products.title
# for fast ILIKE text search without full sequential scans.
class AddTrigramIndexToProducts < ActiveRecord::Migration[7.2]
  def up
    enable_extension 'pg_trgm'
    add_index :products, :title, using: :gin, opclass: :gin_trgm_ops, name: 'index_products_on_title_trgm'
  end

  def down
    remove_index :products, name: 'index_products_on_title_trgm'
    # Don't disable pg_trgm as other code might use it
  end
end
