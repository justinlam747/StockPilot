module Reports
  class WeeklyGenerator
    def initialize(shop, week_start)
      @shop = shop
      @week_start = week_start
    end

    def generate
      raise NotImplementedError
    end
  end
end
