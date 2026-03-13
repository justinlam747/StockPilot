module Agents
  class Runner
    def self.run_all_shops
      results = []

      Shop.active.find_each do |shop|
        ActsAsTenant.with_tenant(shop) do
          result = Agents::InventoryMonitor.new(shop).run
          results << { shop: shop.shop_domain, **result }
        end
      rescue StandardError => e
        Rails.logger.error("[Agents::Runner] Error for #{shop.shop_domain}: #{e.message}")
        results << { shop: shop.shop_domain, error: e.message }
      end

      results
    end

    def self.run_for_shop(shop_id)
      shop = Shop.active.find(shop_id)
      ActsAsTenant.with_tenant(shop) do
        Agents::InventoryMonitor.new(shop).run
      end
    end
  end
end
