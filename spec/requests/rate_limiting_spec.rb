require "rails_helper"

RSpec.describe "Rate limiting", type: :request do
  before do
    Rack::Attack.enabled = true
    Rack::Attack.reset!
  end

  after { Rack::Attack.enabled = false }

  it "throttles excessive requests" do
    70.times { get "/dashboard" }
    expect(response.status).to eq(429)
  end

  it "throttles agent runs" do
    6.times { post "/agents/run" }
    expect(response.status).to eq(429)
  end
end
