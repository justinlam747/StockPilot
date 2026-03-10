require "rails_helper"

RSpec.describe DailySyncAllShopsJob, type: :job do
  it "enqueues InventorySyncJob for each active shop" do
    shop1 = create(:shop)
    shop2 = create(:shop)
    create(:shop, uninstalled_at: Time.current) # inactive

    expect {
      described_class.perform_now
    }.to have_enqueued_job(InventorySyncJob).exactly(2).times
  end
end
