module Shopify
  class InventoryFetcher
    def initialize(shop)
      @shop = shop
    end

    def call
      raise NotImplementedError
    end
  end
end
