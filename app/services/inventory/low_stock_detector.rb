module Inventory
  class LowStockDetector
    def initialize(shop)
      @shop = shop
    end

    def detect
      latest_snapshots = InventorySnapshot
        .select("DISTINCT ON (variant_id) variant_id, available, on_hand, committed, incoming")
        .where(shop_id: @shop.id)
        .order("variant_id, created_at DESC")

      variants = Variant
        .joins(:product)
        .joins("INNER JOIN (#{latest_snapshots.to_sql}) latest ON latest.variant_id = variants.id")
        .where(products: { deleted_at: nil, shop_id: @shop.id })
        .select(
          "variants.*",
          "latest.available AS latest_available",
          "latest.on_hand AS latest_on_hand",
          "latest.committed AS latest_committed",
          "latest.incoming AS latest_incoming"
        )

      variants.filter_map do |v|
        available = v.latest_available.to_i
        on_hand = v.latest_on_hand.to_i
        threshold = v.low_stock_threshold || @shop.low_stock_threshold

        status = if available <= 0
                   :out_of_stock
                 elsif available < threshold
                   :low_stock
                 else
                   :ok
                 end

        next if status == :ok

        {
          variant: v,
          available: available,
          on_hand: on_hand,
          status: status,
          threshold: threshold
        }
      end
    end
  end
end
