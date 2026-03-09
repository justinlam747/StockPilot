module Shopify
  class WebhookRegistrar
    def self.call(shop)
      raise NotImplementedError
    end
  end
end
