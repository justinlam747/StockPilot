class InventorySnapshot < ActiveRecord::Base
  belongs_to :shop
  belongs_to :variant
end
