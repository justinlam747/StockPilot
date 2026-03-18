# frozen_string_literal: true

class AgentInventoryCheckJob < ApplicationJob
  queue_as :default

  retry_on Anthropic::Error, wait: 1.minute, attempts: 2

  def perform(shop_id = nil)
    if shop_id
      Agents::Runner.run_for_shop(shop_id)
    else
      Agents::Runner.run_all_shops
    end
  end
end
