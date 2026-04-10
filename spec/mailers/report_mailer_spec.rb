# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ReportMailer do
  let(:shop) do
    create(:shop, settings: {
             'alert_email' => 'owner@example.com',
             'timezone' => 'America/Toronto'
           })
  end

  let(:report_data) do
    {
      'top_sellers' => [{ 'sku' => 'SKU-001', 'title' => 'Widget', 'units_sold' => 42 }],
      'stockouts' => [],
      'low_sku_count' => 3,
      'reorder_suggestions' => []
    }
  end

  describe '#weekly_summary' do
    let(:mail) { described_class.weekly_summary(shop, report_data) }

    it 'sends to the shop alert_email' do
      expect(mail.to).to eq(['owner@example.com'])
    end

    it 'includes the shop domain in the subject' do
      expect(mail.subject).to include(shop.shop_domain)
    end

    it 'includes top sellers in the body' do
      expect(mail.body.encoded).to include('SKU-001')
      expect(mail.body.encoded).to include('42')
    end

    it 'includes low stock count' do
      expect(mail.body.encoded).to include('3')
    end
  end
end
