class Product < ApplicationRecord
  acts_as_tenant :shop

  has_many :variants, dependent: :destroy

  scope :active, -> { where(deleted_at: nil) }
end
