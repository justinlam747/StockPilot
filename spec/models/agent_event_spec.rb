# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AgentEvent do
  let(:shop) { create(:shop) }
  let(:agent_run) do
    ActsAsTenant.with_tenant(shop) do
      create(:agent_run, shop: shop)
    end
  end

  describe 'associations' do
    subject { create(:agent_event, agent_run: agent_run) }

    it { is_expected.to belong_to(:agent_run) }
  end

  describe 'validations' do
    subject { create(:agent_event, agent_run: agent_run) }

    it { is_expected.to validate_presence_of(:event_type) }
    it { is_expected.to validate_presence_of(:sequence) }

    it do
      expect(subject).to validate_numericality_of(:sequence)
        .only_integer.is_greater_than_or_equal_to(0)
    end

    it 'does not allow duplicate sequence values within the same run' do
      create(:agent_event, agent_run: agent_run, sequence: 3)
      event = build(:agent_event, agent_run: agent_run, sequence: 3)

      expect(event).not_to be_valid
      expect(event.errors[:sequence]).to include('has already been taken')
    end

    it 'allows the same sequence value on a different run' do
      other_run = ActsAsTenant.with_tenant(shop) do
        create(:agent_run, shop: shop)
      end

      create(:agent_event, agent_run: agent_run, sequence: 4)
      event = build(:agent_event, agent_run: other_run, sequence: 4)

      expect(event).to be_valid
    end
  end
end
