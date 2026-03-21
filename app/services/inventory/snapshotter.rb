# frozen_string_literal: true

module Inventory
  # Creates point-in-time inventory snapshots from Shopify data.
  class Snapshotter
    def initialize(shop)
      @shop = shop
    end

    def snapshot(products_data)
      rows = build_snapshot_rows(products_data[:products])
      InventorySnapshot.insert_all(rows) if rows.any?
      rows.size
    end

    private

    def build_snapshot_rows(products)
      products.flat_map { |pn| build_product_rows(pn) }
    end

    def build_product_rows(product_node)
      variant_nodes = product_node.dig('variants', 'nodes') || []
      variant_nodes.filter_map { |vnode| build_variant_row(vnode) }
    end

    def build_variant_row(vnode)
      variant = Variant.find_by(shopify_variant_id: vnode['legacyResourceId'].to_s)
      return unless variant

      quantities = aggregate_quantities(vnode)
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
