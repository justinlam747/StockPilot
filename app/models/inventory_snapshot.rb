# frozen_string_literal: true

# Point-in-time record of a variant's stock levels across all locations.
#
# acts_as_tenant :shop means every query on this model is automatically
# scoped to the current shop (set via ActsAsTenant.current_tenant). This
# prevents data leakage between merchants — a critical multi-tenancy guard.
class InventorySnapshot < ApplicationRecord
  acts_as_tenant :shop

  belongs_to :variant

  validates :available, presence: true, numericality: { only_integer: true }
  validates :on_hand, presence: true, numericality: { only_integer: true }
  validates :committed, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :incoming, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  # -------------------------------------------------------------------------
  # Whitelist of columns that callers may request in .latest_per_variant.
  # This prevents SQL injection — without it, a caller could pass arbitrary
  # SQL fragments (e.g., "1; DROP TABLE ...") into the SELECT clause.
  # -------------------------------------------------------------------------
  ALLOWED_COLUMNS = %w[variant_id available on_hand committed incoming created_at].freeze

  # Returns the most recent snapshot for each variant.
  #
  # How it works:
  #   DISTINCT ON (variant_id) is a PostgreSQL-specific feature. It groups
  #   rows by variant_id, then picks the FIRST row in each group according
  #   to the ORDER BY clause. Since we order by "created_at DESC", the first
  #   row is the newest snapshot — exactly what we want.
  #
  # Why it returns an ActiveRecord::Relation (not an Array):
  #   Returning a relation lets callers chain additional queries on top:
  #     .to_a        → materialize as an array
  #     .index_by    → build a hash keyed by variant_id
  #     .where(...)  → add more filters
  #     .to_sql      → inspect the generated SQL for debugging
  #
  # @param shop_id     [Integer] the shop to query (explicit for clarity)
  # @param variant_ids [Array<Integer>, nil] optional filter to specific variants
  # @param columns     [Array<String>] which columns to SELECT (must be in ALLOWED_COLUMNS)
  # @return [ActiveRecord::Relation]
  def self.latest_per_variant(shop_id:, variant_ids: nil, columns: %w[variant_id available])
    # Validate columns against the whitelist to prevent SQL injection
    invalid_columns = columns - ALLOWED_COLUMNS
    if invalid_columns.any?
      raise ArgumentError, "Invalid columns: #{invalid_columns.join(', ')}. Allowed: #{ALLOWED_COLUMNS.join(', ')}"
    end

    # Build the query — DISTINCT ON requires the ORDER BY to start with the
    # same column(s), then we add created_at DESC to pick the newest row.
    scope = select("DISTINCT ON (variant_id) #{columns.join(', ')}")
            .where(shop_id: shop_id)
            .order('variant_id, created_at DESC')

    # .present? returns true for non-nil, non-empty arrays — a Rails helper
    # that makes nil-safe checks more readable than "if variant_ids && variant_ids.any?"
    scope = scope.where(variant_id: variant_ids) if variant_ids.present?
    scope
  end

  # Returns daily stock totals for chart rendering.
  #
  # Produces a hash like: { Date(2026-04-06) => 150, Date(2026-04-07) => 142, ... }
  # Perfect for feeding into a line chart (x-axis = date, y-axis = total stock).
  #
  # The method zero-fills missing days so the chart always has a continuous
  # x-axis — even if no snapshots were recorded on a particular day, that
  # day appears with a value of 0.
  #
  # @param variant_ids [Array<Integer>] which variants to include
  # @param days        [Integer] how many days of history (default 14)
  # @return [Hash{Date => Integer}] ordered by date ascending
  def self.daily_totals(variant_ids:, days: 14)
    # Step 1: Query the database for daily sums.
    #   DATE(created_at) truncates timestamps to just the date part.
    #   SUM(available) adds up all variant snapshots for each day.
    #   GROUP BY collapses multiple rows into one row per day.
    raw_totals = where(variant_id: variant_ids)
                 .where('created_at >= ?', days.days.ago)
                 .select('DATE(created_at) AS snap_date, SUM(available) AS total_available')
                 .group('DATE(created_at)')
                 .order('snap_date')

    # Step 2: Build a zero-filled hash covering every day in the range.
    #   Ruby ranges with dates iterate one day at a time — (start..end).each
    #   gives us every date in between, inclusive.
    date_map = {}
    ((days - 1).days.ago.to_date..Date.current).each { |date| date_map[date] = 0 }

    # Step 3: Overlay actual totals onto the zero-filled hash.
    #   Each `row` is an ActiveRecord object with virtual attributes
    #   snap_date and total_available (defined by the SELECT aliases above).
    raw_totals.each { |row| date_map[row.snap_date.to_date] = row.total_available.to_i }

    date_map
  end
end
