module Inventory
  class LowStockDetector
    def initialize(shop)
      @shop = shop
    end

    def detect
      raise NotImplementedError
    end
  end
end
