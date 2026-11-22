# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Health check resilience', type: :request do
  it 'returns degraded when database is down' do
    allow(ActiveRecord::Base.connection).to receive(:execute).and_raise(
      ActiveRecord::ConnectionNotEstablished, 'connection refused'
    )

    get '/health'

    expect(response).to have_http_status(:service_unavailable)
    body = JSON.parse(response.body)
    expect(body['status']).to eq('degraded')
    expect(body['error']).to include('connection refused')
  end

  it 'returns degraded when Redis is down' do
    redis_double = instance_double(Redis)
    allow(Redis).to receive(:new).and_return(redis_double)
    allow(redis_double).to receive(:ping).and_raise(Redis::CannotConnectError, 'connection refused')

    get '/health'

    expect(response).to have_http_status(:service_unavailable)
    body = JSON.parse(response.body)
    expect(body['status']).to eq('degraded')
  end

  it 'returns degraded when both Redis and DB are down' do
    allow(ActiveRecord::Base.connection).to receive(:execute).and_raise(
      ActiveRecord::ConnectionNotEstablished, 'DB down'
    )

    get '/health'

    expect(response).to have_http_status(:service_unavailable)
    body = JSON.parse(response.body)
    expect(body['status']).to eq('degraded')
    expect(body['error']).to include('DB down')
  end
end
