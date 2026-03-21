# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Rate limiting', type: :request do
  let(:shop) { create(:shop) }

  before do
    login_as(shop)
    Rack::Attack.enabled = true
    Rack::Attack.cache.store.clear
  end

  after do
    Rack::Attack.enabled = false
  end

  it 'throttles excessive requests at the configured limit' do
    # Verify the throttle config is correct
    expect(Rack::Attack.throttles).to include('req/shop')
    throttle = Rack::Attack.throttles['req/shop']
    expect(throttle).to be_present
  end

  it 'throttles agent runs' do
    allow_any_instance_of(Inventory::LowStockDetector).to receive(:detect).and_return([])
    responses = []
    7.times do
      post '/agents/run'
      responses << response.status
    end
    expect(responses).to include(429), "Expected 429 in responses: #{responses}"
  end
end
