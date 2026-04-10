# frozen_string_literal: true

module Ingestion
  # Shared heuristics for detecting column types from header names and cell values.
  # Used by both PasteParser and CsvParser to suggest column mappings.
  module ColumnDetector
    HEADER_PATTERNS = {
      'sku' => /\b(sku|item[\s_-]?id|product[\s_-]?code|barcode|upc|ean)\b/i,
      'title' => /\b(name|title|product[\s_-]?name|description|item)\b/i,
      'quantity' => /\b(qty|quantity|stock|count|on[\s_-]?hand|available|units)\b/i,
      'price' => /\b(price|cost|unit[\s_-]?price|retail|wholesale)\b/i,
      'supplier' => /\b(supplier|vendor|manufacturer|brand)\b/i
    }.freeze

    module_function

    # Score columns by header name matching.
    # Returns { column_index => field_name } mapping.
    def detect_from_headers(headers)
      return {} if headers.blank?

      mapping = {}
      headers.each_with_index do |header, idx|
        next if header.nil?

        HEADER_PATTERNS.each do |field, pattern|
          if header.to_s.match?(pattern) && !mapping.value?(field)
            mapping[idx.to_s] = field
            break
          end
        end
      end
      mapping
    end

    # Score columns by analyzing cell content patterns.
    # Falls back to this when headers are absent.
    def detect_from_values(rows)
      return {} if rows.blank?

      col_count = rows.map(&:size).max || 0
      mapping = {}

      col_count.times do |col_idx|
        values = rows.map { |row| row[col_idx].to_s.strip }.reject(&:empty?)
        next if values.empty?

        field = score_column(values, rows.size)
        mapping[col_idx.to_s] = field if field && !mapping.value?(field)
      end

      mapping
    end

    # Analyze a column's values and return the most likely field type.
    def score_column(values, total_rows)
      return nil if values.empty?

      if sku_column?(values)
        'sku'
      elsif quantity_column?(values)
        'quantity'
      elsif price_column?(values)
        'price'
      elsif supplier_column?(values, total_rows)
        'supplier'
      elsif name_column?(values)
        'title'
      end
    end

    # SKU: short alphanumeric strings with dashes/underscores
    def sku_column?(values)
      matches = values.count { |v| v.match?(/\A[A-Za-z0-9][\w-]{1,30}\z/) }
      matches > values.size * 0.7
    end

    # Quantity: pure integers, typically < 10000
    def quantity_column?(values)
      matches = values.count { |v| v.match?(/\A\d{1,5}\z/) }
      matches > values.size * 0.8
    end

    # Price: numbers with decimals, possibly $ prefix
    def price_column?(values)
      matches = values.count { |v| v.match?(/\A\$?\d+\.\d{1,2}\z/) }
      matches > values.size * 0.6
    end

    # Supplier: few unique values relative to row count
    def supplier_column?(values, total_rows)
      return false if total_rows < 3

      unique_ratio = values.uniq.size.to_f / values.size
      avg_length = values.sum(&:length).to_f / values.size
      unique_ratio < 0.5 && avg_length > 2 && avg_length < 50
    end

    # Name: longer strings with spaces
    def name_column?(values)
      matches = values.count { |v| v.length > 5 && v.include?(' ') }
      matches > values.size * 0.5
    end
  end
end
