# frozen_string_literal: true

# Liveness/readiness probe checking database and Redis connectivity.
class HealthController < ActionController::API
  def show
    ActiveRecord::Base.connection.execute('SELECT 1')
    redis = Redis.new(url: ENV.fetch('REDIS_URL', nil))
    redis_ok = redis.ping == 'PONG'
    redis.close
    render json: { status: 'ok', db: true, redis: redis_ok }, status: :ok
  rescue StandardError => e
    render json: { status: 'degraded', error: e.message }, status: :service_unavailable
  end
end
