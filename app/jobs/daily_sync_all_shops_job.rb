# frozen_string_literal: true

# Enqueues an inventory sync job for every active shop.
class DailySyncAllShopsJob < ApplicationJob
  queue_as :default

  def perform
    Shop.active.find_each do |shop|
      InventorySyncJob.perform_later(shop.id)
    end
  end
end
