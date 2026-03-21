# frozen_string_literal: true

require 'rails_helper'

RSpec.describe GdprCustomerRedactJob, type: :job do
  let(:shop) { create(:shop) }

  describe '#perform' do
    it 'creates an audit log for the redact request' do
      expect do
        GdprCustomerRedactJob.new.perform(shop.id, 12_345)
      end.to change(AuditLog.where(action: 'gdpr_customer_redact'), :count).by(1)
    end

    it 'handles unknown shop gracefully' do
      expect do
        GdprCustomerRedactJob.new.perform(999_999, 12_345)
      end.not_to raise_error
    end
  end
end
