module Inventory
  class Snapshotter
    def initialize(shop)
      @shop = shop
    end

    def snapshot(products_data)
      raise NotImplementedError
    end
  end
end
