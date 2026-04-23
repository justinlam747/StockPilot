# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AgentRunJob do
  let(:shop) { create(:shop) }

  before do
    ActsAsTenant.current_tenant = shop
  end

  it 'boots the run and delegates execution to the inventory monitor' do
    run = create(:agent_run, shop: shop)
    monitor = instance_double(Agents::InventoryMonitor)

    expect(Agents::InventoryMonitor).to receive(:new).with(shop).and_return(monitor)
    expect(monitor).to receive(:execute).with(run)

    described_class.perform_now(run.id)

    expect(run.reload.status).to eq('running')
    expect(run.started_at).to be_present
  end

  it 'does nothing when the run is no longer queued' do
    run = create(:agent_run, shop: shop, status: 'completed')

    expect(Agents::InventoryMonitor).not_to receive(:new)

    described_class.perform_now(run.id)
  end

  it 'marks the run as failed when the monitor raises' do
    run = create(:agent_run, shop: shop)
    monitor = instance_double(Agents::InventoryMonitor)
    allow(Agents::InventoryMonitor).to receive(:new).and_return(monitor)
    allow(monitor).to receive(:execute).and_raise(StandardError, 'boom')
    allow_any_instance_of(described_class).to receive(:executions).and_return(described_class::MAX_ATTEMPTS)

    described_class.perform_now(run.id)

    expect(run.reload.status).to eq('failed')
    expect(run.error_message).to eq('boom')
    expect(run.events.last.event_type).to eq('error')
  end
end
