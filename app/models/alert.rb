class Alert < ApplicationRecord
  acts_as_tenant :shop

  belongs_to :variant
end
