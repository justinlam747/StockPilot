# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Shop do
  subject(:shop) { create(:shop) }

  describe 'associations' do
    it { is_expected.to have_many(:products).dependent(:destroy) }
    it { is_expected.to have_many(:variants).dependent(:destroy) }
    it { is_expected.to have_many(:inventory_snapshots).dependent(:destroy) }
    it { is_expected.to have_many(:suppliers).dependent(:destroy) }
    it { is_expected.to have_many(:alerts).dependent(:destroy) }
    it { is_expected.to have_many(:purchase_orders).dependent(:destroy) }
    it { is_expected.to have_many(:audit_logs).dependent(:destroy) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:shop_domain) }
    it { is_expected.to validate_uniqueness_of(:shop_domain) }
    it { is_expected.to validate_presence_of(:access_token) }

    it { is_expected.to allow_value('my-store.myshopify.com').for(:shop_domain) }
    it { is_expected.to allow_value('STORE-123.myshopify.com').for(:shop_domain) }
    it { is_expected.not_to allow_value('invalid-domain.com').for(:shop_domain) }
    it { is_expected.not_to allow_value('store.otherdomain.com').for(:shop_domain) }
    it { is_expected.not_to allow_value('').for(:shop_domain) }
    it { is_expected.not_to allow_value('store with spaces.myshopify.com').for(:shop_domain) }
  end

  describe 'scopes' do
    describe '.active' do
      let!(:active_shop) { create(:shop, uninstalled_at: nil) }
      let!(:uninstalled_shop) { create(:shop, uninstalled_at: 1.day.ago) }

      it 'returns only shops that have not been uninstalled' do
        expect(described_class.active).to include(active_shop)
        expect(described_class.active).not_to include(uninstalled_shop)
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
      raw_value = described_class.connection.select_value(
        "SELECT access_token FROM shops WHERE id = #{shop.id}"
      )
      expect(raw_value).not_to eq('shpat_secret_value')
      # But the model decrypts it correctly
      expect(shop.reload.access_token).to eq('shpat_secret_value')
    end
  end
end
