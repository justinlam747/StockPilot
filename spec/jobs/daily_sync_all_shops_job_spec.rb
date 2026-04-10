# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DailySyncAllShopsJob do
  it 'enqueues InventorySyncJob for each active shop' do
    create(:shop)
    create(:shop)
    create(:shop, uninstalled_at: Time.current) # inactive

    expect do
      described_class.perform_now
    end.to have_enqueued_job(InventorySyncJob).exactly(2).times
  end
end
