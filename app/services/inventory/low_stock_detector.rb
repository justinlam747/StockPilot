# frozen_string_literal: true

module Inventory
  # Identifies variants below their low-stock or out-of-stock thresholds.
  class LowStockDetector
    def initialize(shop)
      @shop = shop
    end

    def detect
      variants_with_snapshots.filter_map { |v| evaluate_variant(v) }
    end

    private

    def variants_with_snapshots
      join_sql = Arel.sql("INNER JOIN (#{latest_snapshots_sql}) latest ON latest.variant_id = variants.id")
      Variant.joins(:product).joins(join_sql)
             .where(products: { deleted_at: nil, shop_id: @shop.id })
             .select('variants.*', *snapshot_columns)
    end

    def snapshot_columns
      %w[available on_hand committed incoming].map { |col| "latest.#{col} AS latest_#{col}" }
    end

    def latest_snapshots_sql
      InventorySnapshot
        .select('DISTINCT ON (variant_id) variant_id, available, on_hand, committed, incoming')
        .where(shop_id: @shop.id)
        .order('variant_id, created_at DESC')
        .to_sql
    end

    def evaluate_variant(variant)
      available = variant.latest_available.to_i
      on_hand = variant.latest_on_hand.to_i
      threshold = variant.low_stock_threshold || @shop.low_stock_threshold
      status = stock_status(available, threshold)
      return if status == :ok

      { variant: variant, available: available, on_hand: on_hand,
        status: status, threshold: threshold }
    end

    def stock_status(available, threshold)
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
