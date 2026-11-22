class PrepareShopifyConnector < ActiveRecord::Migration[7.2]
  def up
    create_shops unless table_exists?(:shops)
    add_column :shops, :installation_id, :uuid unless column_exists?(:shops, :installation_id)
    add_column :shops, :refresh_token, :text unless column_exists?(:shops, :refresh_token)
    %i[access_token_expires_at refresh_token_expires_at reauthorization_required_at].each do |column|
      add_column :shops, column, :datetime unless column_exists?(:shops, column)
    end
    create_products unless table_exists?(:products)
    create_variants unless table_exists?(:variants)
    create_snapshots unless table_exists?(:inventory_snapshots)
    add_column :variants, :deleted_at, :datetime unless column_exists?(:variants, :deleted_at)
  end

  def down
    raise ActiveRecord::IrreversibleMigration, 'These tables may contain pre-existing Shopify installations.'
  end

  private

  def create_shops
    create_table :shops do |t|
      t.string :shop_domain, null: false, index: { unique: true }
      t.text :access_token, null: false
      t.datetime :installed_at, null: false
      t.datetime :uninstalled_at
      t.datetime :synced_at
      t.timestamps
    end
  end

  def create_products
    create_table :products do |t|
      t.references :shop, null: false, foreign_key: { on_delete: :cascade }
      t.bigint :shopify_product_id
      t.string :title
      t.datetime :deleted_at
      t.timestamps
      t.index %i[shop_id shopify_product_id], unique: true
    end
  end

  def create_variants
    create_table :variants do |t|
      t.references :shop, null: false, foreign_key: { on_delete: :cascade }
      t.references :product, null: false, foreign_key: { on_delete: :cascade }
      t.bigint :shopify_variant_id
      t.string :title
      t.string :sku
      t.timestamps
      t.index %i[shop_id shopify_variant_id], unique: true
    end
  end

  def create_snapshots
    create_table :inventory_snapshots do |t|
      t.references :shop, null: false, foreign_key: { on_delete: :cascade }
      t.references :variant, null: false, foreign_key: { on_delete: :cascade }
      %i[available on_hand committed incoming].each { |quantity| t.integer quantity, null: false, default: 0 }
      t.datetime :snapshotted_at, null: false
      t.datetime :created_at, null: false
      t.index %i[shop_id variant_id snapshotted_at], name: 'index_stockpilot_snapshots_by_variant'
    end
  end
end
