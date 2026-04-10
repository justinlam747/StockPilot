# frozen_string_literal: true

require 'rails_helper'

RSpec.describe GdprCustomerRedactJob do
  let(:shop) { create(:shop) }

  describe '#perform' do
    it 'creates an audit log for the redact request' do
      expect do
        described_class.new.perform(shop.id, 12_345)
      end.to change(AuditLog.where(action: 'gdpr_customer_redact'), :count).by(1)
    end

    it 'handles unknown shop gracefully' do
      expect do
        described_class.new.perform(999_999, 12_345)
      end.not_to raise_error
    end
  end
end
