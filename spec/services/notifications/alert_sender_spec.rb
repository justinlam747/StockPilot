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

  it "fires outgoing webhooks when active endpoints exist" do
    create(:webhook_endpoint, shop: shop, event_type: "low_stock", is_active: true)

    expect {
      sender.send_low_stock_alerts(flagged_variants)
    }.to have_enqueued_job(WebhookDeliveryJob)
  end

  it "does not send email when alert_email is nil" do
    shop.update!(settings: shop.settings.merge("alert_email" => nil))

    expect {
      sender.send_low_stock_alerts(flagged_variants)
    }.to change { Alert.count }.by(1)
      .and not_have_enqueued_mail(AlertMailer, :low_stock)
  end

  it "creates alerts for multiple flagged variants" do
    product2 = create(:product, shop: shop)
    variant2 = create(:variant, shop: shop, product: product2)

    multi_flagged = [
      { variant: variant, available: 3, on_hand: 3, status: :low_stock, threshold: 10 },
      { variant: variant2, available: 0, on_hand: 0, status: :out_of_stock, threshold: 10 }
    ]

    expect {
      sender.send_low_stock_alerts(multi_flagged)
    }.to change { Alert.count }.by(2)
  end
end
