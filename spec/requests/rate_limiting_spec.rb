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

  it 'throttles excessive dashboard requests' do
    responses = []
    65.times do
      get '/dashboard'
      responses << response.status
    end
    expect(responses).to include(429), "Expected 429 in responses: #{responses}"
  end
end
