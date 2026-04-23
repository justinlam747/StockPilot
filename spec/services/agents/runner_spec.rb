# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Agents::Runner do
  include ActiveJob::TestHelper

  let!(:shop) { create(:shop) }

  before do
    ActiveJob::Base.queue_adapter = :test
    clear_enqueued_jobs
    clear_performed_jobs
  end

  after do
    clear_enqueued_jobs
    clear_performed_jobs
  end

  describe '.run_for_shop' do
    it 'creates a queued run and enqueues the job' do
      expect do
        @run = described_class.run_for_shop(shop.id, goal: 'Focus on urgent stockouts')
      end.to change(AgentRun, :count).by(1)

      expect(@run.status).to eq('queued')
      expect(@run.goal).to eq('Focus on urgent stockouts')
      expect(@run.input_payload['goal']).to eq('Focus on urgent stockouts')
      expect(enqueued_jobs.last[:job]).to eq(AgentRunJob)
      expect(enqueued_jobs.last[:args]).to eq([@run.id])
    end

    it 'stores correction context and parent linkage on follow-up runs' do
      parent_run = create(:agent_run, shop: shop, summary: 'Original summary')

      child_run = described_class.run_for_shop(
        shop.id,
        goal: parent_run.goal,
        correction: 'Ignore supplierless SKUs this pass',
        parent_run: parent_run
      )

      expect(child_run.parent_run).to eq(parent_run)
      expect(child_run.trigger_source).to eq('retry')
      expect(child_run.input_payload['correction']).to eq('Ignore supplierless SKUs this pass')
      expect(child_run.input_payload['previous_summary']).to eq('Original summary')
    end

    it 'reuses an active run instead of queueing a duplicate' do
      active_run = create(:agent_run, shop: shop, status: 'running')

      expect do
        run = described_class.run_for_shop(shop.id, goal: 'Duplicate request')
        expect(run).to eq(active_run)
      end.not_to change(AgentRun, :count)

      expect(enqueued_jobs).to be_empty
    end
  end

  describe '.run_all_shops' do
    it 'queues runs for all active shops' do
      other_shop = create(:shop)

      expect do
        runs = described_class.run_all_shops
        expect(runs.map(&:shop_id)).to contain_exactly(shop.id, other_shop.id)
        expect(runs.map(&:trigger_source)).to all(eq('scheduled'))
      end.to change(AgentRun, :count).by(2)
    end
  end
end
