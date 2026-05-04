# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Agents' do
  include ActiveJob::TestHelper

  let(:shop) { create(:shop) }

  before do
    login_as(shop)
    ActiveJob::Base.queue_adapter = :test
    clear_enqueued_jobs
    clear_performed_jobs
  end

  after do
    clear_enqueued_jobs
    clear_performed_jobs
  end

  describe 'GET /agents' do
    it 'returns success' do
      get '/agents'

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Agents')
    end
  end

  describe 'GET /agents/:id' do
    it 'renders run details, timeline, and actions' do
      run = create(:agent_run, shop: shop, summary: 'Stock risk summary')
      create(:agent_event, agent_run: run, event_type: 'summary', content: 'Stock risk summary')
      create(:agent_action, agent_run: run, title: 'Review reorder')

      get "/agents/#{run.id}"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Stock risk summary')
      expect(response.body).to include('Review reorder')
      expect(response.body).to include('Correct This Run')
    end
  end

  describe 'POST /agents/run' do
    it 'queues a new agent run' do
      expect do
        post '/agents/run', params: { goal: 'Focus on apparel stockouts' }
      end.to(change { AgentRun.unscoped.count }.by(1))

      expect(response).to redirect_to(agent_path(AgentRun.unscoped.last))
      expect(AgentRun.unscoped.last.input_payload['goal']).to eq('Focus on apparel stockouts')
    end
  end

  describe 'POST /agents/:id/corrections' do
    it 'queues a child run with correction guidance' do
      parent_run = create(:agent_run, shop: shop, goal: 'Original goal')

      expect do
        post "/agents/#{parent_run.id}/corrections", params: { correction: 'Ignore supplierless SKUs' }
      end.to(change { AgentRun.unscoped.count }.by(1))

      child_run = AgentRun.unscoped.last
      expect(response).to redirect_to(agent_path(child_run))
      expect(child_run.parent_run).to eq(parent_run)
      expect(child_run.input_payload['correction']).to eq('Ignore supplierless SKUs')
    end

    it 'rejects blank correction text' do
      run = create(:agent_run, shop: shop)

      expect do
        post "/agents/#{run.id}/corrections", params: { correction: '   ' }
      end.not_to(change { AgentRun.unscoped.count })

      expect(response).to redirect_to(agent_path(run))
      expect(flash[:alert]).to eq('Correction cannot be blank')
    end

    it 'returns not found for a run owned by another shop' do
      other_shop = create(:shop)
      foreign_run = ActsAsTenant.with_tenant(other_shop) do
        create(:agent_run, shop: other_shop)
      end

      get "/agents/#{foreign_run.id}"

      expect(response).to have_http_status(:not_found)
    end

    it 'does not allow corrections against a foreign run' do
      other_shop = create(:shop)
      foreign_run = ActsAsTenant.with_tenant(other_shop) do
        create(:agent_run, shop: other_shop)
      end

      expect do
        post "/agents/#{foreign_run.id}/corrections", params: { correction: 'Ignore this' }
      end.not_to(change { AgentRun.unscoped.count })

      expect(response).to have_http_status(:not_found)
    end
  end
end
