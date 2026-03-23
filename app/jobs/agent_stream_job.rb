# frozen_string_literal: true

# Tier 3: Live Agent Stream — runs the inventory monitor agent in background,
# publishing each step to Redis pub/sub for real-time SSE streaming.
# Steps are also persisted to agent_runs.steps for replay on reconnect.
class AgentStreamJob
  include Sidekiq::Job

  sidekiq_options queue: :default, retry: 2

  def perform(agent_run_id)
    @run = AgentRun.find(agent_run_id)
    @run.update!(status: 'running', started_at: Time.current)
    execute_agent
  rescue StandardError => e
    fail_run(e)
  ensure
    redis&.close
  end

  private

  def execute_agent
    shop = Shop.active.find(@run.shop_id)
    ActsAsTenant.with_tenant(shop) do
      agent = Agents::InventoryMonitor.new(
        shop, provider: @run.provider, model: @run.model,
              stream_callback: method(:publish_step)
      )
      complete_run(agent.run)
    end
  end

  def publish_step(step_data)
    @run.reload
    return if @run.cancelled?

    @run.steps << step_data
    @run.save!

    redis.publish("agent_stream:#{@run.id}", {
      event: step_data[:event] || 'step',
      data: step_data
    }.to_json)
  end

  def complete_run(result)
    @run.update!(
      status: 'completed', completed_at: Time.current,
      results: result, turns: result[:turns] || 0
    )
    publish_event('complete', result)
    @run.shop.update!(last_agent_run_at: Time.current, last_agent_results: result)
  end

  def fail_run(error)
    @run&.update!(status: 'failed', completed_at: Time.current, error_message: error.message)
    publish_event('error', { message: 'Agent run failed', error_class: error.class.name })
    Sentry.capture_exception(error) if defined?(Sentry)
  end

  def publish_event(event, data)
    redis.publish("agent_stream:#{@run.id}", { event: event, data: data }.to_json)
  end

  def redis
    @redis ||= Redis.new(url: ENV.fetch('REDIS_URL'))
  end
end
