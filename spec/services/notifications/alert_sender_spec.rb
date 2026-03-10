require "rails_helper"

RSpec.describe Notifications::AlertSender do
  let(:shop) { create(:shop, settings: { "alert_email" => "test@example.com", "low_stock_threshold" => 10 }) }
  let(:sender) { described_class.new(shop) }

  before { ActsAsTenant.current_tenant = shop }

  let(:product) { create(:product, shop: shop) }
  let(:variant) { create(:variant, shop: shop, product: product) }

  let(:flagged_variants) do
    [{ variant: variant, available: 3, on_hand: 3, status: :low_stock, threshold: 10 }]
  end

  it "creates alert and enqueues email for new low-stock variant" do
    expect {
      sender.send_low_stock_alerts(flagged_variants)
    }.to change { Alert.count }.by(1)
      .and have_enqueued_mail(AlertMailer, :low_stock)
  end

  it "does not create duplicate alert for same variant on same day" do
    create(:alert, shop: shop, variant: variant, triggered_at: Time.current)

    expect {
      sender.send_low_stock_alerts(flagged_variants)
    }.not_to change { Alert.count }
  end

  it "does nothing for empty flagged variants" do
    expect {
      sender.send_low_stock_alerts([])
    }.not_to change { Alert.count }
  end
end
