# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Notifications::AlertSender do
  let(:shop) { create(:shop, settings: { 'alert_email' => 'test@example.com', 'low_stock_threshold' => 10 }) }
  let(:sender) { described_class.new(shop) }

  before { ActsAsTenant.current_tenant = shop }

  let(:product) { create(:product, shop: shop) }
  let(:variant) { create(:variant, shop: shop, product: product) }

  let(:flagged_variants) do
    [{ variant: variant, available: 3, on_hand: 3, status: :low_stock, threshold: 10 }]
  end

  it 'creates alert and enqueues email for new low-stock variant' do
    expect do
      sender.send_low_stock_alerts(flagged_variants)
    end.to change { Alert.count }.by(1)
                                 .and have_enqueued_mail(AlertMailer, :low_stock)
  end

  it 'does not create duplicate alert for same variant on same day' do
    create(:alert, shop: shop, variant: variant, triggered_at: Time.current)

    expect do
      sender.send_low_stock_alerts(flagged_variants)
    end.not_to(change { Alert.count })
  end

  it 'does nothing for empty flagged variants' do
    expect do
      sender.send_low_stock_alerts([])
    end.not_to(change { Alert.count })
  end

  it 'does not send email when alert_email is nil' do
    shop.update!(settings: shop.settings.merge('alert_email' => nil))

    expect do
      sender.send_low_stock_alerts(flagged_variants)
    end.to change { Alert.count }.by(1)

    expect(ActionMailer::Base.deliveries).to be_empty
  end

  it 'creates alerts for multiple flagged variants' do
    product2 = create(:product, shop: shop)
    variant2 = create(:variant, shop: shop, product: product2)

    multi_flagged = [
      { variant: variant, available: 3, on_hand: 3, status: :low_stock, threshold: 10 },
      { variant: variant2, available: 0, on_hand: 0, status: :out_of_stock, threshold: 10 }
    ]

    expect do
      sender.send_low_stock_alerts(multi_flagged)
    end.to change { Alert.count }.by(2)
  end
end
