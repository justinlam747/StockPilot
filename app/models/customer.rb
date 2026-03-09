class Customer < ApplicationRecord
  acts_as_tenant :shop
end
