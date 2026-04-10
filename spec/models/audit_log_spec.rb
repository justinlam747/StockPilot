# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AuditLog do
  let(:shop) { create(:shop) }

  describe 'associations' do
    it { is_expected.to belong_to(:shop).optional }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:action) }
  end

  it 'records an event' do
    log = described_class.record(action: 'login', shop: shop, metadata: { source: 'oauth' })
    expect(log).to be_persisted
    expect(log.action).to eq('login')
    expect(log.shop).to eq(shop)
    expect(log.metadata['source']).to eq('oauth')
  end

  it 'is readonly once persisted' do
    log = described_class.record(action: 'test', shop: shop)
    expect { log.update!(action: 'changed') }.to raise_error(ActiveRecord::ReadOnlyRecord)
  end

  it 'allows nil shop for unauthenticated events' do
    log = described_class.record(action: 'login_failed', metadata: { reason: 'invalid_shop' })
    expect(log).to be_persisted
    expect(log.shop).to be_nil
  end
end
