# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Shop, type: :model do
  subject(:shop) { create(:shop) }

  describe 'associations' do
    it { should have_many(:products).dependent(:destroy) }
    it { should have_many(:variants).dependent(:destroy) }
    it { should have_many(:inventory_snapshots).dependent(:destroy) }
    it { should have_many(:suppliers).dependent(:destroy) }
    it { should have_many(:alerts).dependent(:destroy) }
    it { should have_many(:purchase_orders).dependent(:destroy) }
    it { should have_many(:audit_logs).dependent(:destroy) }
  end

  describe 'scopes' do
    describe '.active' do
      let!(:active_shop) { create(:shop, uninstalled_at: nil) }
      let!(:uninstalled_shop) { create(:shop, uninstalled_at: 1.day.ago) }

      it 'returns only shops that have not been uninstalled' do
        expect(Shop.active).to include(active_shop)
        expect(Shop.active).not_to include(uninstalled_shop)
      end
    end
  end

  describe '#timezone' do
    it 'returns the configured timezone from settings' do
      shop.settings['timezone'] = 'America/New_York'
      expect(shop.timezone).to eq('America/New_York')
    end

    it 'defaults to America/Toronto when no timezone is set' do
      shop.settings.delete('timezone')
      expect(shop.timezone).to eq('America/Toronto')
    end
  end

  describe '#low_stock_threshold' do
    it 'returns the configured threshold from settings' do
      shop.settings['low_stock_threshold'] = 25
      expect(shop.low_stock_threshold).to eq(25)
    end

    it 'defaults to 10 when no threshold is set' do
      shop.settings.delete('low_stock_threshold')
      expect(shop.low_stock_threshold).to eq(10)
    end
  end

  describe '#alert_email' do
    it 'returns the configured alert email from settings' do
      shop.settings['alert_email'] = 'alerts@example.com'
      expect(shop.alert_email).to eq('alerts@example.com')
    end

    it 'returns nil when no alert email is set' do
      shop.settings.delete('alert_email')
      expect(shop.alert_email).to be_nil
    end
  end

  describe 'encryption' do
    it 'encrypts the access_token attribute' do
      shop = create(:shop, access_token: 'shpat_secret_value')
      # Verify the raw database value is not the plaintext token
      raw_value = Shop.connection.select_value(
        "SELECT access_token FROM shops WHERE id = #{shop.id}"
      )
      expect(raw_value).not_to eq('shpat_secret_value')
      # But the model decrypts it correctly
      expect(shop.reload.access_token).to eq('shpat_secret_value')
    end
  end
end
