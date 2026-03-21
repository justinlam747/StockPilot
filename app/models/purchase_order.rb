# frozen_string_literal: true

# A restock order sent to a supplier with one or more line items.
class PurchaseOrder < ApplicationRecord
  acts_as_tenant :shop

  belongs_to :supplier
  has_many :line_items, class_name: 'PurchaseOrderLineItem', dependent: :destroy
  accepts_nested_attributes_for :line_items

  STATUSES = %w[draft sent received cancelled].freeze

  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :order_date, presence: true
  validates :expected_delivery, comparison: { greater_than_or_equal_to: :order_date }, allow_nil: true, if: lambda {
    order_date.present? && expected_delivery.present?
  }

  scope :draft, -> { where(status: 'draft') }
  scope :sent, -> { where(status: 'sent') }
  scope :received, -> { where(status: 'received') }

  before_validation :set_defaults, on: :create

  private

  def set_defaults
    self.order_date ||= Date.current
    self.status ||= 'draft'
  end
end
