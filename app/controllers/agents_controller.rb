# frozen_string_literal: true

# Tier 3: Live Agent Stream — async agent execution with real-time SSE streaming.
# POST /agents/run_async starts a background agent run.
# GET  /agents/stream/:id streams steps via Server-Sent Events.
class AgentsController < ApplicationController # rubocop:disable Metrics/ClassLength
  include ActionController::Live

  ALLOWED_PROVIDERS = %w[anthropic openai google].freeze
  ALLOWED_MODELS = {
    'anthropic' => %w[claude-sonnet-4-20250514 claude-haiku-4-5-20251001],
    'openai' => %w[gpt-4o gpt-4o-mini o3-mini],
    'google' => %w[gemini-2.0-flash gemini-2.5-pro-preview-06-05]
  }.freeze

  STREAM_TIMEOUT = 5.minutes
  HEARTBEAT_INTERVAL = 15 # seconds

  skip_before_action :verify_authenticity_token, only: [:run_async]
  before_action :verify_csrf_via_header, only: [:run_async]

  def run_async
    return render json: { error: 'Agent already running' }, status: :conflict if concurrent_run_exists?

    run = create_agent_run
    AgentStreamJob.perform_async(run.id)
    audit_agent_start(run)

    render json: { run_id: run.id }, status: :accepted
  end

  def stream
    run = AgentRun.find_by!(id: params[:id], shop_id: current_shop.id)
    set_sse_headers

    run.completed? || run.failed? ? send_replay(run) : stream_live(run)
  rescue ActionController::Live::ClientDisconnected, IOError
    # Browser navigated away — clean up silently
  ensure
    response.stream.close
  end

  private

  def concurrent_run_exists?
    AgentRun.where(shop_id: current_shop.id, status: %w[pending running]).exists?
  end

  def create_agent_run
    provider, model = validated_provider_model
    AgentRun.create!(shop: current_shop, status: 'pending', provider: provider, model: model)
  end

  def audit_agent_start(run)
    AuditLog.record(action: 'agent_run_async', shop: current_shop, request: request,
                    metadata: { agent_run_id: run.id })
  end

  def set_sse_headers
    response.headers['Content-Type'] = 'text/event-stream'
    response.headers['Cache-Control'] = 'no-cache'
    response.headers['X-Accel-Buffering'] = 'no'
    response.headers['Connection'] = 'keep-alive'
  end

  def verify_csrf_via_header
    token = request.headers['X-CSRF-Token']
    return if valid_authenticity_token?(session, token)

    render json: { error: 'Invalid CSRF token' }, status: :unprocessable_entity
  end

  def validated_provider_model
    provider = params[:provider]&.downcase&.strip
    model = params[:model]&.strip
    return [nil, nil] if provider.blank? && model.blank?

    validate_provider!(provider)
    validate_model!(provider, model)
    [provider, model]
  end

  def validate_provider!(provider)
    raise ArgumentError, 'Invalid provider' unless provider.blank? || ALLOWED_PROVIDERS.include?(provider)
  end

  def validate_model!(provider, model)
    return unless model.present? && provider.present?

    allowed = ALLOWED_MODELS[provider] || []
    raise ArgumentError, 'Invalid model for provider' unless allowed.include?(model)
  end

  def send_replay(run)
    replay_persisted_steps(run)
    event = run.completed? ? 'complete' : 'error'
    data = run.completed? ? run.results : { message: run.error_message || 'Agent run failed' }
    sse_write(event, data)
  end

  def stream_live(run)
    redis = Redis.new(url: ENV.fetch('REDIS_URL'))
    started_at = Time.current
    replay_persisted_steps(run)
    subscribe_to_events(redis, run, started_at)
  rescue ActionController::Live::ClientDisconnected, IOError
    # Client disconnected
  ensure
    redis&.close
  end

  def replay_persisted_steps(run)
    run.steps.each_with_index do |step, i|
      sse_write('step', step.merge('index' => i))
    end
  end

  def subscribe_to_events(redis, run, started_at)
    redis.subscribe("agent_stream:#{run.id}") do |on|
      on.message do |_channel, message|
        check_timeout!(started_at, redis)
        event = JSON.parse(message)
        sse_write(event['event'], event['data'])
        redis.unsubscribe if %w[complete error].include?(event['event'])
      end
    end
  end

  def check_timeout!(started_at, redis)
    return unless Time.current - started_at > STREAM_TIMEOUT

    redis.unsubscribe
  end

  def sse_write(event, data)
    response.stream.write("event: #{event}\ndata: #{data.to_json}\n\n")
  end
end
