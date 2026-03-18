# frozen_string_literal: true

# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[7.2].define(version: 20_250_318_000_002) do
  # These are extensions that must be enabled in order to support this database
  enable_extension 'plpgsql'

  create_table 'alerts', force: :cascade do |t|
    t.bigint 'shop_id', null: false
    t.bigint 'variant_id', null: false
    t.string 'alert_type', null: false
    t.string 'channel', null: false
    t.string 'status', default: 'sent', null: false
    t.datetime 'triggered_at', precision: nil, default: -> { 'now()' }, null: false
    t.jsonb 'metadata', default: {}
    t.datetime 'created_at', precision: nil, default: -> { 'now()' }, null: false
    t.integer 'threshold'
    t.integer 'current_quantity'
    t.boolean 'dismissed', default: false, null: false
    t.index %w[shop_id dismissed], name: 'index_alerts_on_shop_id_and_dismissed'
    t.index %w[shop_id variant_id triggered_at], name: 'idx_alerts_variant_day'
    t.index ['shop_id'], name: 'index_alerts_on_shop_id'
    t.index ['variant_id'], name: 'index_alerts_on_variant_id'
  end

  create_table 'audit_logs', force: :cascade do |t|
    t.bigint 'shop_id'
    t.string 'action', null: false
    t.string 'ip_address'
    t.string 'user_agent'
    t.string 'request_id'
    t.jsonb 'metadata', default: {}
    t.datetime 'created_at', null: false
    t.index ['action'], name: 'index_audit_logs_on_action'
    t.index ['created_at'], name: 'index_audit_logs_on_created_at'
    t.index %w[shop_id created_at], name: 'index_audit_logs_on_shop_id_and_created_at'
    t.index ['shop_id'], name: 'index_audit_logs_on_shop_id'
  end

  create_table 'inventory_snapshots', force: :cascade do |t|
    t.bigint 'shop_id', null: false
    t.bigint 'variant_id', null: false
    t.integer 'available', default: 0, null: false
    t.integer 'on_hand', default: 0, null: false
    t.integer 'committed', default: 0, null: false
    t.integer 'incoming', default: 0, null: false
    t.datetime 'snapshotted_at', precision: nil, default: -> { 'now()' }, null: false
    t.datetime 'created_at', precision: nil, default: -> { 'now()' }, null: false
    t.index %w[shop_id snapshotted_at], name: 'idx_snapshots_shop_time'
    t.index ['shop_id'], name: 'index_inventory_snapshots_on_shop_id'
    t.index %w[variant_id snapshotted_at], name: 'idx_snapshots_variant_time', order: { snapshotted_at: :desc }
    t.index ['variant_id'], name: 'index_inventory_snapshots_on_variant_id'
  end

  create_table 'products', force: :cascade do |t|
    t.bigint 'shop_id', null: false
    t.bigint 'shopify_product_id', null: false
    t.string 'title'
    t.string 'product_type'
    t.string 'vendor'
    t.string 'status'
    t.datetime 'deleted_at', precision: nil
    t.datetime 'synced_at', precision: nil
    t.datetime 'created_at', null: false
    t.datetime 'updated_at', null: false
    t.index %w[shop_id shopify_product_id], name: 'index_products_on_shop_id_and_shopify_product_id', unique: true
    t.index %w[shop_id status], name: 'index_products_on_shop_id_and_status'
    t.index ['shop_id'], name: 'index_products_on_shop_id'
  end

  create_table 'purchase_order_line_items', force: :cascade do |t|
    t.bigint 'purchase_order_id', null: false
    t.bigint 'variant_id', null: false
    t.string 'sku'
    t.string 'title'
    t.integer 'qty_ordered', default: 0, null: false
    t.integer 'qty_received', default: 0, null: false
    t.decimal 'unit_price', precision: 10, scale: 2
    t.datetime 'created_at', null: false
    t.datetime 'updated_at', null: false
    t.index ['purchase_order_id'], name: 'index_purchase_order_line_items_on_purchase_order_id'
    t.index ['variant_id'], name: 'index_purchase_order_line_items_on_variant_id'
  end

  create_table 'purchase_orders', force: :cascade do |t|
    t.bigint 'shop_id', null: false
    t.bigint 'supplier_id', null: false
    t.string 'po_number'
    t.string 'status', default: 'draft', null: false
    t.text 'draft_body'
    t.datetime 'sent_at', precision: nil
    t.datetime 'created_at', null: false
    t.datetime 'updated_at', null: false
    t.date 'order_date'
    t.date 'expected_delivery'
    t.text 'po_notes'
    t.index %w[shop_id status], name: 'index_purchase_orders_on_shop_id_and_status'
    t.index ['shop_id'], name: 'index_purchase_orders_on_shop_id'
    t.index ['supplier_id'], name: 'index_purchase_orders_on_supplier_id'
  end

  create_table 'shops', force: :cascade do |t|
    t.string 'shop_domain', null: false
    t.string 'access_token', null: false
    t.string 'plan', default: 'free'
    t.datetime 'installed_at', precision: nil, default: -> { 'now()' }, null: false
    t.datetime 'uninstalled_at', precision: nil
    t.datetime 'synced_at', precision: nil
    t.jsonb 'settings', default: {}, null: false
    t.datetime 'created_at', null: false
    t.datetime 'updated_at', null: false
    t.datetime 'last_agent_run_at'
    t.jsonb 'last_agent_results', default: {}
    t.index ['shop_domain'], name: 'index_shops_on_shop_domain', unique: true
  end

  create_table 'suppliers', force: :cascade do |t|
    t.bigint 'shop_id', null: false
    t.string 'name', null: false
    t.string 'email'
    t.string 'contact_name'
    t.integer 'lead_time_days', default: 7
    t.text 'notes'
    t.datetime 'created_at', null: false
    t.datetime 'updated_at', null: false
    t.integer 'star_rating', default: 0
    t.text 'rating_notes'
    t.string 'phone'
    t.index %w[shop_id name], name: 'index_suppliers_on_shop_id_and_name'
    t.index ['shop_id'], name: 'index_suppliers_on_shop_id'
  end

  create_table 'variants', force: :cascade do |t|
    t.bigint 'shop_id', null: false
    t.bigint 'product_id', null: false
    t.bigint 'supplier_id'
    t.bigint 'shopify_variant_id', null: false
    t.bigint 'shopify_inventory_item_id'
    t.string 'sku'
    t.string 'title'
    t.decimal 'price', precision: 10, scale: 2
    t.integer 'low_stock_threshold'
    t.datetime 'created_at', null: false
    t.datetime 'updated_at', null: false
    t.index ['product_id'], name: 'index_variants_on_product_id'
    t.index %w[shop_id shopify_variant_id], name: 'index_variants_on_shop_id_and_shopify_variant_id', unique: true
    t.index %w[shop_id sku], name: 'index_variants_on_shop_id_and_sku'
    t.index ['shop_id'], name: 'index_variants_on_shop_id'
    t.index ['supplier_id'], name: 'index_variants_on_supplier_id'
  end

  add_foreign_key 'alerts', 'shops', on_delete: :cascade
  add_foreign_key 'alerts', 'variants', on_delete: :cascade
  add_foreign_key 'audit_logs', 'shops'
  add_foreign_key 'inventory_snapshots', 'shops', on_delete: :cascade
  add_foreign_key 'inventory_snapshots', 'variants', on_delete: :cascade
  add_foreign_key 'products', 'shops', on_delete: :cascade
  add_foreign_key 'purchase_order_line_items', 'purchase_orders', on_delete: :cascade
  add_foreign_key 'purchase_order_line_items', 'variants'
  add_foreign_key 'purchase_orders', 'shops', on_delete: :cascade
  add_foreign_key 'purchase_orders', 'suppliers'
  add_foreign_key 'suppliers', 'shops', on_delete: :cascade
  add_foreign_key 'variants', 'products', on_delete: :cascade
  add_foreign_key 'variants', 'shops', on_delete: :cascade
  add_foreign_key 'variants', 'suppliers', on_delete: :nullify
end
