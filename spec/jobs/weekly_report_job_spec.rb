# frozen_string_literal: true

require 'rails_helper'

RSpec.describe WeeklyReportJob, type: :job do
  let(:shop) do
    create(:shop, settings: {
             'low_stock_threshold' => 10,
             'timezone' => 'America/Toronto',
             'alert_email' => 'owner@example.com'
           })
  end

  let(:product) { create(:product, shop: shop) }
  let(:variant) { create(:variant, shop: shop, product: product) }

  before do
    ActsAsTenant.with_tenant(shop) do
      create(:inventory_snapshot, shop: shop, variant: variant, available: 50, on_hand: 55)
    end
  end

  describe '#perform' do
    it 'generates a report and sends email for a specific shop' do
      mailer_double = double('mailer', deliver_later: nil)
      allow(ReportMailer).to receive(:weekly_summary).and_return(mailer_double)

      WeeklyReportJob.new.perform(shop.id)

      expect(ReportMailer).to have_received(:weekly_summary).with(shop, kind_of(Hash))
    end

    it 'skips email when shop has no alert_email' do
      shop.update!(settings: { 'timezone' => 'America/Toronto' })
      allow(ReportMailer).to receive(:weekly_summary)

      WeeklyReportJob.new.perform(shop.id)

      expect(ReportMailer).not_to have_received(:weekly_summary)
    end

    it 'runs for all active shops when no shop_id provided' do
      mailer_double = double('mailer', deliver_later: nil)
      allow(ReportMailer).to receive(:weekly_summary).and_return(mailer_double)

      WeeklyReportJob.new.perform

      expect(ReportMailer).to have_received(:weekly_summary).at_least(:once)
    end

    it 'captures errors without crashing the whole job' do
      allow_any_instance_of(Reports::WeeklyGenerator).to receive(:generate).and_raise(StandardError, 'boom')

      expect { WeeklyReportJob.new.perform(shop.id) }.not_to raise_error
    end
  end
end
