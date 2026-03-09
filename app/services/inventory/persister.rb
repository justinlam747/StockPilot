module Inventory
  class Persister
    def initialize(shop)
      @shop = shop
    end

    def upsert(data)
      raise NotImplementedError
    end

    def upsert_single_product(shopify_data)
      raise NotImplementedError
    end
  end
end
