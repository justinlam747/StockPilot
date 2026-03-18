# frozen_string_literal: true

class HealthController < ActionController::API
  def show
    ActiveRecord::Base.connection.execute('SELECT 1')
    redis = Redis.new(url: ENV['REDIS_URL'])
    redis_ok = redis.ping == 'PONG'
    redis.close
    render json: { status: 'ok', db: true, redis: redis_ok }, status: :ok
  rescue StandardError => e
    render json: { status: 'degraded', error: e.message }, status: :service_unavailable
  end
end
