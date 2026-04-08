# frozen_string_literal: true

module Reports
  # Compiles weekly inventory metrics: top sellers, stockouts, and reorder suggestions.
  class WeeklyGenerator
    def initialize(shop, week_start)
      @shop = shop
      @week_start = week_start.beginning_of_day
      @week_end = @week_start + 7.days
    end

    def compile_weekly_report
      {
        'top_sellers' => top_sellers,
        'stockouts' => stockouts,
        'low_sku_count' => low_sku_count,
        'reorder_suggestions' => reorder_suggestions
      }
    end

    private

    def top_sellers
      start_map = snapshot_map(@week_start, @week_start + 1.day, 'ASC')
      end_map = snapshot_map(@week_end - 1.day, @week_end, 'DESC')
      sold = compute_units_sold(start_map, end_map)
      format_top_sellers(sold.first(10))
    end

    def snapshot_map(range_start, range_end, order_dir)
      snapshots = InventorySnapshot
                  .select('DISTINCT ON (variant_id) variant_id, available')
                  .where(created_at: range_start..range_end)
                  .order("variant_id, created_at #{order_dir}")
      rows = ActiveRecord::Base.connection.select_rows(
        "SELECT variant_id, available FROM (#{snapshots.to_sql}) AS snaps"
      )
      rows.to_h { |row| [row[0].to_i, row[1].to_i] }
    end

    def compute_units_sold(start_map, end_map)
      sold = start_map.filter_map do |vid, start_qty|
        units = start_qty - (end_map[vid] || 0)
        { variant_id: vid, units_sold: units } if units.positive?
      end
      sold.sort_by { |s| -s[:units_sold] }
    end

    def format_top_sellers(top)
      variants = Variant.where(id: top.map { |s| s[:variant_id] })
                        .includes(:product).index_by(&:id)
      top.filter_map do |s|
        v = variants[s[:variant_id]]
        next unless v

        { 'sku' => v.sku,
          'title' => "#{v.product.title} — #{v.title}",
          'units_sold' => s[:units_sold] }
      end
    end

    def stockouts
      Alert
        .where(shop_id: @shop.id, alert_type: 'out_of_stock', triggered_at: @week_start..@week_end)
        .includes(variant: :product)
        .map { |alert| format_stockout(alert) }
    end

    def format_stockout(alert)
      {
        'sku' => alert.variant.sku,
        'title' => "#{alert.variant.product.title} — #{alert.variant.title}",
        'triggered_at' => alert.triggered_at.iso8601
      }
    end

    def low_sku_count
      flagged_variants.size
    end

    def reorder_suggestions
      grouped = group_by_supplier(flagged_variants)
      suppliers = Supplier.where(id: grouped.keys).index_by(&:id)
      grouped.map { |sid, variants| format_suggestion(suppliers[sid], variants) }
    end

    # Memoizes the result of LowStockDetector so it only runs once per report.
    # The ||= operator means: "if @flagged_variants is nil, compute it; otherwise reuse it."
    # This avoids running the expensive DISTINCT ON query twice.
    def flagged_variants
      @flagged_variants ||= Inventory::LowStockDetector.new(@shop).detect
    end

    def group_by_supplier(flagged)
      flagged.select { |fv| fv[:variant].supplier_id.present? }
             .group_by { |fv| fv[:variant].supplier_id }
    end

    def format_suggestion(supplier, variants)
      {
        'supplier_name' => supplier&.name || 'Unknown',
        'supplier_email' => supplier&.email,
        'items' => variants.map { |fv| format_reorder_item(fv) }
      }
    end

    def format_reorder_item(flagged)
      threshold = flagged[:threshold]
      {
        'sku' => flagged[:variant].sku,
        'title' => flagged[:variant].title,
        'available' => flagged[:available],
        'suggested_qty' => [(threshold * 2) - flagged[:available], threshold].max
      }
    end
  end
end
