module Notifications
  class AlertSender
    def initialize(shop)
      @shop = shop
    end

    def send_low_stock_alerts(flagged_variants)
      raise NotImplementedError
    end
  end
end
