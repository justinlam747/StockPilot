# frozen_string_literal: true

module Reports
  class WeeklyGenerator
    def initialize(shop, week_start)
      @shop = shop
      @week_start = week_start.beginning_of_day
      @week_end = @week_start + 7.days
    end

    def generate
      {
        'top_sellers' => top_sellers,
        'stockouts' => stockouts,
        'low_sku_count' => low_sku_count,
        'reorder_suggestions' => reorder_suggestions
      }
    end

    private

    def top_sellers
      start_snapshots = InventorySnapshot
                        .select('DISTINCT ON (variant_id) variant_id, available')
                        .where(created_at: @week_start..(@week_start + 1.day))
                        .order('variant_id, created_at ASC')

      end_snapshots = InventorySnapshot
                      .select('DISTINCT ON (variant_id) variant_id, available')
                      .where(created_at: (@week_end - 1.day)..@week_end)
                      .order('variant_id, created_at DESC')

      start_map = ActiveRecord::Base.connection
                                    .select_rows("SELECT variant_id, available FROM (#{start_snapshots.to_sql}) AS start_snaps")
                                    .map do |row|
        [row[0].to_i,
         row[1].to_i]
      end
                                                                .to_h

      end_map = ActiveRecord::Base.connection
                                  .select_rows("SELECT variant_id, available FROM (#{end_snapshots.to_sql}) AS end_snaps")
                                  .map do |row|
        [row[0].to_i,
         row[1].to_i]
      end
                                                            .to_h

      sold = start_map.filter_map do |vid, start_qty|
        end_qty = end_map[vid] || 0
        units_sold = start_qty - end_qty
        next if units_sold <= 0

        { variant_id: vid, units_sold: units_sold }
      end

      top = sold.sort_by { |s| -s[:units_sold] }.first(10)

      variants = Variant.where(id: top.map { |s| s[:variant_id] }).includes(:product).index_by(&:id)

      top.map do |s|
        v = variants[s[:variant_id]]
        next unless v

        {
          'sku' => v.sku,
          'title' => "#{v.product.title} — #{v.title}",
          'units_sold' => s[:units_sold]
        }
      end.compact
    end

    def stockouts
      Alert
        .where(shop_id: @shop.id, alert_type: 'out_of_stock', triggered_at: @week_start..@week_end)
        .includes(variant: :product)
        .map do |alert|
          {
            'sku' => alert.variant.sku,
            'title' => "#{alert.variant.product.title} — #{alert.variant.title}",
            'triggered_at' => alert.triggered_at.iso8601
          }
        end
    end

    def low_sku_count
      Inventory::LowStockDetector.new(@shop).detect.size
    end

    def reorder_suggestions
      flagged = Inventory::LowStockDetector.new(@shop).detect
      by_supplier = flagged.select { |fv| fv[:variant].supplier_id.present? }
                           .group_by { |fv| fv[:variant].supplier_id }

      suppliers = Supplier.where(id: by_supplier.keys).index_by(&:id)

      by_supplier.map do |supplier_id, variants|
        supplier = suppliers[supplier_id]
        {
          'supplier_name' => supplier&.name || 'Unknown',
          'supplier_email' => supplier&.email,
          'items' => variants.map do |fv|
            threshold = fv[:threshold]
            {
              'sku' => fv[:variant].sku,
              'title' => fv[:variant].title,
              'available' => fv[:available],
              'suggested_qty' => [threshold * 2 - fv[:available], threshold].max
            }
          end
        }
      end
    end
  end
end
