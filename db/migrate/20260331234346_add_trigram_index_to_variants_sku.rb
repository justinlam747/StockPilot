# frozen_string_literal: true

# Adds a GIN trigram index on variants.sku for fast ILIKE search.
# The pg_trgm extension is already enabled by the products title migration.
class AddTrigramIndexToVariantsSku < ActiveRecord::Migration[7.2]
  def up
    add_index :variants, :sku, using: :gin, opclass: :gin_trgm_ops, name: 'index_variants_on_sku_trgm'
  end

  def down
    remove_index :variants, name: 'index_variants_on_sku_trgm'
  end
end
