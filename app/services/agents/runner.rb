# frozen_string_literal: true

module Agents
  # Orchestrates inventory monitor agent runs across shops.
  class Runner
    def self.run_all_shops
      results = []
      Shop.active.find_each { |shop| results << run_shop_safely(shop) }
      results
    end

    def self.run_for_shop(shop_id)
      shop = Shop.active.find(shop_id)
      ActsAsTenant.with_tenant(shop) do
        Agents::InventoryMonitor.new(shop).run
      end
    end

    def self.run_shop_safely(shop)
      ActsAsTenant.with_tenant(shop) do
        result = Agents::InventoryMonitor.new(shop).run
        { shop: shop.shop_domain, **result }
      end
    rescue StandardError => e
      Rails.logger.error("[Agents::Runner] Error for #{shop.shop_domain}: #{e.message}")
      { shop: shop.shop_domain, error: e.message }
    end

    private_class_method :run_shop_safely
  end
end
