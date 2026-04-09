# frozen_string_literal: true

module Inventory
  # Creates point-in-time inventory snapshots from Shopify data.
  class Snapshotter
    def initialize(shop)
      @shop = shop
    end

    def create_snapshots_from_shopify_data(data)
      rows = build_snapshot_rows_for_all_products(data[:products])
      # insert_all is a bulk insert — it sends one SQL INSERT with all rows instead of
      # saving each row individually. Much faster when you have many rows to save at once.
      InventorySnapshot.insert_all(rows) if rows.any?
      rows.size
    end

    private

    def build_snapshot_rows_for_all_products(products)
      products.flat_map { |pn| build_product_rows(pn) }
    end

    def build_product_rows(product_node)
      variant_nodes = product_node.dig('variants', 'nodes') || []
      variant_nodes.filter_map { |variant_node| build_one_snapshot_row(variant_node) }
    end

    def build_one_snapshot_row(variant_node)
      variant = Variant.find_by(shopify_variant_id: variant_node['legacyResourceId'].to_s)
      return unless variant

      quantities = aggregate_quantities(variant_node)
      {
        shop_id: @shop.id, variant_id: variant.id,
        available: quantities[:available], on_hand: quantities[:on_hand],
        committed: quantities[:committed], incoming: quantities[:incoming],
        created_at: Time.current
      }
    end

    def aggregate_quantities(variant_node)
      levels = variant_node.dig('inventoryItem', 'inventoryLevels', 'nodes') || []
      totals = { available: 0, on_hand: 0, committed: 0, incoming: 0 }

      levels.each do |level|
        (level['quantities'] || []).each do |q|
          key = q['name'].to_sym
          totals[key] += q['quantity'].to_i if totals.key?(key)
        end
      end

      totals
    end
  end
end
