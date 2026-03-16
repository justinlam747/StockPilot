require "rails_helper"

RSpec.describe AfterAuthenticateJob, type: :job do
  let(:shop) { create(:shop) }

  it "registers webhooks and enqueues InventorySyncJob" do
    expect(Shopify::WebhookRegistrar).to receive(:call).with(shop)

    expect {
      described_class.perform_now(shop_domain: shop.shop_domain)
    }.to have_enqueued_job(InventorySyncJob).with(shop.id)
  end

  it "discards when shop not found" do
    expect {
      described_class.perform_now(shop_domain: "nonexistent.myshopify.com")
    }.not_to raise_error
  end
end
