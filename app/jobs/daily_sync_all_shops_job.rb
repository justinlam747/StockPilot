# frozen_string_literal: true

class DailySyncAllShopsJob < ApplicationJob
  queue_as :default

  def perform
    Shop.active.find_each do |shop|
      InventorySyncJob.perform_later(shop.id)
    end
  end
end
