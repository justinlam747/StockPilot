class PurchaseOrder < ApplicationRecord
  acts_as_tenant :shop

  belongs_to :supplier
  has_many :line_items, class_name: "PurchaseOrderLineItem", dependent: :destroy
  accepts_nested_attributes_for :line_items
end
