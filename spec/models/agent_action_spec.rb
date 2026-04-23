# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AgentAction do
  let(:shop) { create(:shop) }
  let(:agent_run) do
    ActsAsTenant.with_tenant(shop) do
      create(:agent_run, shop: shop)
    end
  end

  describe 'associations' do
    subject { create(:agent_action, agent_run: agent_run) }

    it { is_expected.to belong_to(:agent_run) }
  end

  describe 'validations' do
    subject { create(:agent_action, agent_run: agent_run) }

    it { is_expected.to validate_presence_of(:action_type) }
    it { is_expected.to validate_presence_of(:status) }
    it { is_expected.to validate_inclusion_of(:status).in_array(described_class::STATUSES) }
  end
end
