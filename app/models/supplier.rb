# frozen_string_literal: true

# A vendor supplying products to the merchant's store.
class Supplier < ApplicationRecord
  acts_as_tenant :shop

  has_many :variants, dependent: :nullify
  has_many :purchase_orders, dependent: :restrict_with_error

  validates :name, presence: true, length: { maximum: 255 }
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true
  validates :lead_time_days, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
  validates :star_rating, numericality: { only_integer: true, in: 0..5 }, allow_nil: true
end
