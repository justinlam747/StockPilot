# frozen_string_literal: true

module Ingestion
  # Takes confirmed rows with final column mapping and persists products,
  # variants, and inventory snapshots into the database.
  class ImportPersister
    def initialize(shop, import, rows, mapping)
      @shop = shop
      @import = import
      @rows = rows
      @mapping = normalize_mapping(mapping)
      @imported = 0
      @skipped = 0
      @errors = []
    end

    def persist!
      ActiveRecord::Base.transaction do
        @rows.each_with_index do |row, idx|
          persist_row(row, idx)
        end

        finalize_import
      end

      invalidate_cache

      { imported: @imported, skipped: @skipped, errors: @errors }
    end

    private

    def normalize_mapping(mapping)
      mapping.transform_keys(&:to_s)
    end

    def persist_row(row, idx)
      values = extract_values(row)
      title = values['title'].presence || "Imported Item #{idx + 1}"
      sku = values['sku'].presence

      product = find_or_create_product(title)
      variant = find_or_create_variant(product, sku, values)
      create_snapshot(variant, values['quantity'])
      link_supplier(variant, values['supplier'])

      @imported += 1
    rescue StandardError => e
      @skipped += 1
      @errors << { row: idx + 1, error: e.message }
    end

    def extract_values(row)
      result = {}
      @mapping.each do |col_idx, field|
        result[field] = row[col_idx.to_i]&.strip
      end
      result
    end

    def find_or_create_product(title)
      Product.find_or_create_by!(shop_id: @shop.id, title: title) do |p|
        p.source = 'import'
      end
    end

    def find_or_create_variant(product, sku, values)
      attrs = { shop_id: @shop.id, product: product }
      attrs[:sku] = sku if sku.present?

      variant = find_existing_variant(product, sku)
      if variant
        update_variant_price(variant, values['price'])
        variant
      else
        create_variant(product, sku, values)
      end
    end

    def find_existing_variant(_product, sku)
      return if sku.blank?

      Variant.find_by(shop_id: @shop.id, sku: sku)
    end

    def create_variant(product, sku, values)
      Variant.create!(
        shop_id: @shop.id,
        product: product,
        sku: sku,
        title: 'Default Title',
        source: 'import',
        price: parse_price(values['price'])
      )
    end

    def update_variant_price(variant, price_str)
      price = parse_price(price_str)
      variant.update!(price: price) if price
    end

    def parse_price(price_str)
      return nil if price_str.blank?

      price_str.to_s.gsub(/[^\d.]/, '').to_f
    end

    def create_snapshot(variant, quantity_str)
      qty = quantity_str.to_s.gsub(/[^\d]/, '').to_i

      InventorySnapshot.create!(
        shop_id: @shop.id,
        variant: variant,
        available: qty,
        on_hand: qty,
        committed: 0,
        incoming: 0
      )
    end

    def link_supplier(variant, supplier_name)
      return if supplier_name.blank?

      supplier = Supplier.find_by(
        shop_id: @shop.id,
        name: supplier_name
      )
      variant.update!(supplier: supplier) if supplier
    end

    def finalize_import
      @import.update!(
        status: 'completed',
        imported_rows: @imported,
        skipped_rows: @skipped,
        errors_log: @errors,
        completed_at: Time.current
      )
    end

    def invalidate_cache
      Cache::ShopCache.new(@shop).invalidate_all
    end
  end
end
