# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Health Check' do
  describe 'GET /health' do
    context 'when all services are up' do
      before do
        redis = instance_double(Redis, ping: 'PONG', close: true)
        allow(Redis).to receive(:new).and_return(redis)
      end

      it 'returns ok status with db and redis true' do
        get '/health'

        expect(response).to have_http_status(:ok)

        body = response.parsed_body
        expect(body['status']).to eq('ok')
        expect(body['db']).to be true
        expect(body['redis']).to be true
      end
    end

    context 'when Redis is down' do
      before do
        allow(Redis).to receive(:new).and_raise(Redis::CannotConnectError.new('Connection refused'))
      end

      it 'returns degraded status with 503' do
        get '/health'

        expect(response).to have_http_status(:service_unavailable)

        body = response.parsed_body
        expect(body['status']).to eq('degraded')
        expect(body['error']).to be_present
      end
    end

    context 'when DB is down' do
      before do
        allow(ActiveRecord::Base.connection).to receive(:execute)
          .and_raise(ActiveRecord::ConnectionNotEstablished.new('Connection refused'))
      end

      it 'returns degraded status with 503' do
        get '/health'

        expect(response).to have_http_status(:service_unavailable)

        body = response.parsed_body
        expect(body['status']).to eq('degraded')
        expect(body['error']).to be_present
      end
    end

    it 'does not require authentication' do
      get '/health'

      expect(response).not_to have_http_status(:unauthorized)
    end
  end
end
