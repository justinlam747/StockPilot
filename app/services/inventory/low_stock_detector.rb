# frozen_string_literal: true

module Inventory
  # Identifies variants below their low-stock or out-of-stock thresholds.
  #
  # Used by:
  #   - InventorySyncJob (to trigger alerts for variants that need restocking)
  #   - WeeklyGenerator (to list which SKUs need reordering)
  #
  # For just counting low/out-of-stock variants (without loading them),
  # use InventorySnapshot.count_by_stock_status instead — it's much faster.
  #
  class LowStockDetector
    def initialize(shop)
      @shop = shop
    end

    def detect
      # filter_map is like .map but automatically removes nil results.
      # evaluate_variant returns nil for healthy variants, so they get skipped.
      variants_with_latest_stock.filter_map { |variant| evaluate_variant(variant) }
    end

    private

    def variants_with_latest_stock
      # Use the shared latest_per_variant query from InventorySnapshot.
      # We need all 4 stock columns, not just 'available'.
      latest_sql = InventorySnapshot.latest_per_variant(
        shop_id: @shop.id,
        columns: %w[variant_id available on_hand committed incoming]
      ).to_sql

      # Arel.sql() marks a string as safe SQL. This is OK here because
      # latest_sql comes from ActiveRecord (not user input).
      join_sql = Arel.sql("INNER JOIN (#{latest_sql}) latest ON latest.variant_id = variants.id")
      Variant.joins(:product).joins(join_sql)
             .where(products: { deleted_at: nil, shop_id: @shop.id })
             .select('variants.*', *snapshot_columns)
    end

    def snapshot_columns
      %w[available on_hand committed incoming].map { |col| "latest.#{col} AS latest_#{col}" }
    end

    def evaluate_variant(variant)
      available = variant.latest_available.to_i
      on_hand = variant.latest_on_hand.to_i
      threshold = variant.low_stock_threshold || @shop.low_stock_threshold
      status = determine_stock_status(available, threshold)
      return if status == :ok

      { variant: variant, available: available, on_hand: on_hand,
        status: status, threshold: threshold }
    end

    # Renamed from stock_status to avoid confusion with the status field on models.
    def determine_stock_status(available, threshold)
      if available <= 0
        :out_of_stock
      elsif available < threshold
        :low_stock
      else
        :ok
      end
    end
  end
end
