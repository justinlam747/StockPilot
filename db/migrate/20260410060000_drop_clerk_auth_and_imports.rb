# frozen_string_literal: true

# Removes the half-built Clerk auth + CSV import tables.
#
# Clerk was an earlier architectural experiment (multi-tenant user accounts
# each owning multiple Shopify stores). The integration was never completed
# and is being ripped out in favor of direct Shopify OAuth where each shop
# is its own tenant root.
#
# The imports table backed a separate CSV/paste import feature that has
# also been removed — inventory syncs now happen exclusively through the
# Shopify Admin API.
class DropClerkAuthAndImports < ActiveRecord::Migration[7.2]
  COMPOSITE_INDEX = 'index_shops_on_user_id_and_shop_domain'
  SINGLE_INDEX = 'index_shops_on_user_id'

  def up
    drop_shops_user_link
    drop_users_self_fk
    drop_table :imports if table_exists?(:imports)
    drop_table :users if table_exists?(:users)
  end

  def down
    raise ActiveRecord::IrreversibleMigration,
          'Clerk auth and imports have been removed permanently. ' \
          'Rolling back would require restoring from a pre-removal backup.'
  end

  private

  # shops.user_id was added + enforced NOT NULL by earlier migrations;
  # drop the foreign key, indexes, and column before dropping users.
  def drop_shops_user_link
    remove_foreign_key :shops, :users if foreign_key_exists?(:shops, :users)
    remove_index :shops, name: COMPOSITE_INDEX if index_exists?(:shops, %i[user_id shop_domain], name: COMPOSITE_INDEX)
    remove_index :shops, name: SINGLE_INDEX if index_exists?(:shops, :user_id, name: SINGLE_INDEX)
    remove_column :shops, :user_id if column_exists?(:shops, :user_id)
  end

  # users.active_shop_id referenced shops; drop that FK before dropping users.
  def drop_users_self_fk
    return unless foreign_key_exists?(:users, :shops, column: :active_shop_id)

    remove_foreign_key :users, column: :active_shop_id
  end
end
