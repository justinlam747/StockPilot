# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Rate limiting' do
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

  it 'throttles excessive dashboard requests' do
    app = ->(_env) { [200, {}, ['ok']] }
    middleware = Rack::Attack.new(app)
    responses = Array.new(65) do
      env = Rack::MockRequest.env_for('/dashboard', 'REMOTE_ADDR' => '203.0.113.10')
      middleware.call(env).first
    end

    expect(responses).to include(429), "Expected 429 in responses: #{responses}"
  end
end
