# frozen_string_literal: true

module Ingestion
  # Heuristic parser for unformatted text pasted by merchants.
  # Detects delimiter, parses rows, identifies headers, and suggests column mapping.
  class PasteParser
    HEADER_WORDS = %w[sku name title qty quantity price supplier stock product].freeze
    DELIMITERS = ["\t", ',', '|'].freeze

    def initialize(raw_text)
      @raw_text = raw_text.to_s
    end

    def parse
      lines = extract_lines
      return empty_result if lines.empty?

      delimiter = detect_delimiter(lines)
      rows = parse_rows(lines, delimiter)
      headers, data_rows = separate_headers(rows)
      mapping = build_mapping(headers, data_rows)

      {
        rows: data_rows,
        headers: headers,
        suggested_mapping: mapping,
        delimiter: delimiter
      }
    end

    private

    def extract_lines
      @raw_text.lines.map(&:strip).reject(&:empty?)
    end

    def empty_result
      { rows: [], headers: nil, suggested_mapping: {}, delimiter: nil }
    end

    # Detect delimiter by scoring each candidate across all lines.
    def detect_delimiter(lines)
      best = detect_from_candidates(lines)
      best || detect_space_delimiter(lines)
    end

    def detect_from_candidates(lines)
      DELIMITERS.each do |delim|
        counts = lines.map { |l| l.count(delim) }
        # A valid delimiter appears consistently (same count per line, > 0)
        if counts.min&.positive? && counts.uniq.size <= 2
          return delim
        end
      end
      nil
    end

    def detect_space_delimiter(lines)
      if lines.any? { |l| l.match?(/\s{2,}/) }
        '  ' # 2+ space delimiter
      else
        "\t" # fallback
      end
    end

    def parse_rows(lines, delimiter)
      lines.map do |line|
        if delimiter == '  '
          line.split(/\s{2,}/).map(&:strip)
        else
          line.split(delimiter).map(&:strip)
        end
      end
    end

    # Detect header row: first row containing header-like words.
    def separate_headers(rows)
      return [nil, rows] if rows.empty?

      first_row = rows.first
      if header_row?(first_row)
        [first_row, rows[1..]]
      else
        [nil, rows]
      end
    end

    def header_row?(row)
      header_count = row.count do |cell|
        HEADER_WORDS.any? { |w| cell.to_s.downcase.include?(w) }
      end
      header_count >= 1
    end

    def build_mapping(headers, data_rows)
      if headers
        ColumnDetector.detect_from_headers(headers)
      else
        ColumnDetector.detect_from_values(data_rows)
      end
    end
  end
end
