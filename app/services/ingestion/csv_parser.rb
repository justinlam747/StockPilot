# frozen_string_literal: true

require 'csv'

module Ingestion
  # Parses CSV file content using Ruby's CSV library.
  # Extracts headers, parses rows, and suggests column mapping.
  class CsvParser
    def initialize(content)
      @content = content.to_s
    end

    def parse
      table = CSV.parse(@content, headers: true, liberal_parsing: true)
      headers = table.headers.map { |h| h.to_s.strip }
      rows = extract_rows(table)
      mapping = ColumnDetector.detect_from_headers(headers)

      # Fall back to value-based detection if header matching missed columns
      if mapping.empty?
        mapping = ColumnDetector.detect_from_values(rows)
      end

      {
        rows: rows,
        headers: headers,
        suggested_mapping: mapping,
        delimiter: ','
      }
    end

    private

    def extract_rows(table)
      table.map { |row| row.fields.map { |f| f.to_s.strip } }
    end
  end
end
