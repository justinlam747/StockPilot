# frozen_string_literal: true

require 'rails_helper'

RSpec.describe GdprCustomerDataJob do
  let(:shop) { create(:shop) }

  describe '#perform' do
    it 'creates an audit log for the data request' do
      expect do
        described_class.new.perform(shop.id, 12_345)
      end.to change(AuditLog.where(action: 'gdpr_customer_data_export'), :count).by(1)
    end

    it 'handles unknown shop gracefully' do
      expect do
        described_class.new.perform(999_999, 12_345)
      end.not_to raise_error
    end

    it 'does not create audit log for unknown shop' do
      expect do
        described_class.new.perform(999_999, 12_345)
      end.not_to change(AuditLog, :count)
    end
  end
end
