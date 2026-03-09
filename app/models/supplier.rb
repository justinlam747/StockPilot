class Supplier < ApplicationRecord
  acts_as_tenant :shop

  has_many :variants, dependent: :nullify
  has_many :purchase_orders, dependent: :restrict_with_error
end
