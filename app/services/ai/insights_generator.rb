module AI
  class InsightsGenerator
    def initialize(shop)
      @shop = shop
    end

    def generate
      raise NotImplementedError
    end
  end
end
