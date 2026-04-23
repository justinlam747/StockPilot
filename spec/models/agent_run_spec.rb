# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AgentRun do
  let(:shop) { create(:shop) }

  describe 'associations' do
    subject do
      ActsAsTenant.with_tenant(shop) do
        create(:agent_run, shop: shop)
      end
    end

    it 'belongs to a shop' do
      reflection = described_class.reflect_on_association(:shop)

      expect(reflection).to be_present
      expect(reflection.macro).to eq(:belongs_to)
    end

    it { is_expected.to belong_to(:parent_run).class_name('AgentRun').optional }
    it { is_expected.to have_many(:events).class_name('AgentEvent').dependent(:destroy) }
    it { is_expected.to have_many(:actions).class_name('AgentAction').dependent(:destroy) }
  end

  describe 'validations' do
    subject do
      ActsAsTenant.with_tenant(shop) do
        create(:agent_run, shop: shop)
      end
    end

    it { is_expected.to validate_presence_of(:agent_kind) }
    it { is_expected.to validate_inclusion_of(:agent_kind).in_array(described_class::AGENT_KINDS) }
    it { is_expected.to validate_presence_of(:status) }
    it { is_expected.to validate_inclusion_of(:status).in_array(described_class::STATUSES) }
    it { is_expected.to validate_presence_of(:trigger_source) }
    it { is_expected.to validate_inclusion_of(:trigger_source).in_array(described_class::TRIGGER_SOURCES) }

    it do
      expect(subject).to validate_numericality_of(:progress_percent)
        .only_integer.is_greater_than_or_equal_to(0).is_less_than_or_equal_to(100)
    end

    it do
      expect(subject).to validate_numericality_of(:turns_count)
        .only_integer.is_greater_than_or_equal_to(0)
    end

    it 'is invalid when finished_at is before started_at' do
      ActsAsTenant.with_tenant(shop) do
        run = build(:agent_run, shop: shop, started_at: Time.current, finished_at: 1.minute.ago)

        expect(run).not_to be_valid
        expect(run.errors[:finished_at]).to include('must be on or after started_at')
      end
    end

    it 'is invalid when parent_run belongs to a different shop' do
      other_shop = create(:shop)
      parent_run = ActsAsTenant.with_tenant(other_shop) do
        create(:agent_run, shop: other_shop)
      end

      ActsAsTenant.with_tenant(shop) do
        run = build(:agent_run, shop: shop, parent_run: parent_run)

        expect(run).not_to be_valid
        expect(run.errors[:parent_run]).to include('must belong to the same shop')
      end
    end

    it 'normalizes nil payload hashes to empty hashes' do
      ActsAsTenant.with_tenant(shop) do
        run = build(:agent_run, shop: shop, input_payload: nil, result_payload: nil, metadata: nil)

        expect(run).to be_valid
        run.validate
        expect(run.input_payload).to eq({})
        expect(run.result_payload).to eq({})
        expect(run.metadata).to eq({})
      end
    end

    it 'uses database-backed defaults for new runs' do
      ActsAsTenant.with_tenant(shop) do
        run = described_class.create!(shop: shop)

        expect(run.agent_kind).to eq('inventory_monitor')
        expect(run.status).to eq('queued')
        expect(run.trigger_source).to eq('manual')
        expect(run.progress_percent).to eq(0)
        expect(run.turns_count).to eq(0)
        expect(run.input_payload).to eq({})
      end
    end
  end

  describe 'tenant scoping' do
    it 'automatically scopes to the current tenant' do
      run = ActsAsTenant.with_tenant(shop) do
        create(:agent_run, shop: shop)
      end

      other_shop = create(:shop)
      other_run = ActsAsTenant.with_tenant(other_shop) do
        create(:agent_run, shop: other_shop)
      end

      ActsAsTenant.with_tenant(shop) do
        expect(described_class.all).to include(run)
        expect(described_class.all).not_to include(other_run)
      end
    end
  end
end
