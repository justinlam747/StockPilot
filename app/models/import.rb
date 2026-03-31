# frozen_string_literal: true

# Tracks a data ingestion session (CSV upload, pasted text, or Shopify sync).
class Import < ApplicationRecord
  acts_as_tenant :shop

  SOURCES = %w[csv paste shopify].freeze
  STATUSES = %w[pending previewing confirmed completed failed].freeze

  validates :source, presence: true, inclusion: { in: SOURCES }
  validates :status, presence: true, inclusion: { in: STATUSES }
end
