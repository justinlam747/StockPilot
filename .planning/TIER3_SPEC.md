# TIER 3 SPEC: StockPilot "Holy Shit" Features

**Date:** 2026-03-21
**Author:** Claude (technical spec from codebase analysis)
**Codebase Snapshot:** Rails 7.2, ERB + HTMX + Propshaft, PostgreSQL 16, Redis 7, Sidekiq 7, multi-provider LLM (Anthropic/OpenAI/Google)

---

## Table of Contents

1. [Live Agent Stream](#1-live-agent-stream)
2. [Predictive Stockout Timeline](#2-predictive-stockout-timeline)
3. [One-Click Reorder Flow](#3-one-click-reorder-flow)
4. [Competitive Demo Mode](#4-competitive-demo-mode)
5. [Implementation Order](#5-implementation-order)
6. [Cross-Cutting Concerns](#6-cross-cutting-concerns)

---

## 1. Live Agent Stream

### 1.1 Problem Statement

Today, `POST /agents/run` blocks the HTTP request while the agent runs through up to 5 LLM turns. The HTMX spinner shows "Analyzing..." then dumps all log entries at once with a stagger animation (`agent-stream.js`). The merchant has zero visibility into what the agent is doing, and if the run takes >30s, the request risks timeout on Heroku/Railway/Render (which enforce 30s request timeouts by default).

### 1.2 Architecture Decision: Turbo Streams over SSE (not ActionCable, not raw WebSocket)

```
                     Browser                          Server
                   +---------+                     +----------+
                   |  HTMX   |                     |  Rails   |
                   |  POST   |----POST /agents/--->|  enqueue |
                   | /agents |    run_async        |  Sidekiq |
                   | /run    |<---202 + stream_id--|  job     |
                   |         |                     +----------+
                   |         |                          |
                   |  SSE    |                     +----v-----+
                   |  Event  |<===== SSE =========| AgentRun  |
                   | Source  |  GET /agents/       |  Sidekiq  |
                   |  JS     |  stream/:id         |  Job      |
                   |         |                     |           |
                   |         |  event: step        | Redis     |
                   |         |  data: {step JSON}  | pub/sub   |
                   |         |                     |           |
                   |         |  event: complete    |           |
                   |         |  data: {results}    |           |
                   +---------+                     +-----------+
```

**Why SSE over ActionCable:**

| Criterion | ActionCable | SSE (raw) | Turbo Streams + SSE |
|-----------|-------------|-----------|---------------------|
| Complexity | High (WebSocket, Redis adapter, channel auth) | Medium | Medium (but fits Rails convention) |
| Heroku compat | Requires separate dyno or Redis adapter | Works on standard dyno | Works on standard dyno |
| Connection overhead | Full duplex (unnecessary — this is one-way) | Unidirectional (correct fit) | Unidirectional |
| Reconnection | Manual | Built into EventSource API | Built in |
| CSP impact | Needs `connect-src wss://` | Needs `connect-src` for same-origin (already allowed) | Same |
| Memory per conn | ~50KB (WebSocket + channel state) | ~2KB (thin HTTP keepalive) | ~2KB |
| Shopify iframe | WebSocket upgrade can fail in embedded iframes | HTTP/1.1 chunked works everywhere | Works |
| Our frontend | HTMX, no Turbo/Stimulus | Native JS EventSource | Would need @hotwired/turbo |

**Decision: Raw SSE.** ActionCable is overkill for one-way streaming. We don't use Hotwire/Turbo anywhere in the app (it's HTMX + ERB), so adding Turbo Streams just for this creates a framework split. Raw SSE with vanilla JS `EventSource` fits the existing architecture perfectly.

**Why not long-polling:** Long-polling creates N requests for N steps. SSE is a single persistent connection. With 5 agent turns generating 10-15 log events, long-polling would create 10-15 request/response cycles vs 1 SSE connection.

### 1.3 Detailed Design

#### 1.3.1 Agent Run Lifecycle

```
1. Merchant clicks "Run Analysis"
2. POST /agents/run_async → creates AgentRun record (status: pending), enqueues job, returns 202 + run_id
3. JS opens EventSource to GET /agents/stream/:run_id
4. Sidekiq job starts, publishes steps to Redis pub/sub channel: agent_stream:{run_id}
5. SSE controller subscribes to Redis channel, forwards events to browser
6. On completion, Sidekiq job publishes "complete" event, SSE controller closes connection
7. Browser renders final results, closes EventSource
```

#### 1.3.2 Database Changes

```ruby
# Migration: create_agent_runs
create_table :agent_runs do |t|
  t.bigint :shop_id, null: false
  t.string :status, null: false, default: 'pending'  # pending, running, completed, failed, cancelled
  t.string :provider                                   # anthropic, openai, google
  t.string :model                                      # claude-sonnet-4-20250514, etc.
  t.integer :turns, default: 0
  t.jsonb :results, default: {}                        # final results hash
  t.jsonb :steps, default: []                          # persisted log for replay
  t.datetime :started_at
  t.datetime :completed_at
  t.text :error_message
  t.timestamps

  t.index [:shop_id, :created_at], order: { created_at: :desc }
  t.index [:shop_id, :status]
end
add_foreign_key :agent_runs, :shops, on_delete: :cascade
```

**Why persist steps?** Three reasons: (1) if the SSE connection drops, the browser can replay from persisted steps on reconnect; (2) the merchant can review past runs; (3) debugging agent behavior in production.

#### 1.3.3 Redis Pub/Sub Channel Design

```
Channel name: agent_stream:{run_id}

Event format (JSON):
{
  "event": "step" | "tool_call" | "tool_result" | "thinking" | "complete" | "error",
  "data": {
    "index": 0,           // monotonic step counter
    "timestamp": "...",
    "message": "...",     // human-readable
    "detail": {}          // event-type-specific payload
  }
}

Complete event includes full results hash (same shape as current last_agent_results).
```

**Channel lifetime:** Redis pub/sub channels are ephemeral — they exist only while there are subscribers. The Sidekiq job publishes regardless of whether anyone is listening. If no one is connected, messages are simply dropped (the persisted `steps` array in the DB is the source of truth).

**Per-shop concurrency:** Only one agent run per shop at a time. The `POST /agents/run_async` endpoint checks for `AgentRun.where(shop_id:, status: [:pending, :running]).exists?` and returns 409 Conflict if one is already in progress. This prevents two concurrent runs from creating duplicate alerts or POs (the exact race condition flagged in the pre-commit checklist).

#### 1.3.4 API Endpoints

```ruby
# routes.rb additions
post '/agents/run_async', to: 'agents#run_async'
get  '/agents/stream/:id', to: 'agents#stream'
get  '/agents/runs',       to: 'agents#index'      # history (optional, v2)
get  '/agents/runs/:id',   to: 'agents#show'        # replay (optional, v2)
```

**`POST /agents/run_async`**
```ruby
class AgentsController < ApplicationController
  def run_async
    # Prevent concurrent runs
    if AgentRun.where(shop_id: current_shop.id, status: %w[pending running]).exists?
      return render json: { error: 'Agent already running' }, status: :conflict
    end

    run = AgentRun.create!(
      shop: current_shop,
      status: 'pending',
      provider: validated_provider,
      model: validated_model
    )

    AgentStreamJob.perform_async(run.id)
    AuditLog.record(action: 'agent_run_async', shop: current_shop, request: request,
                    metadata: { agent_run_id: run.id })

    render json: { run_id: run.id }, status: :accepted
  end
end
```

**`GET /agents/stream/:id`** (SSE endpoint)
```ruby
def stream
  run = AgentRun.find_by!(id: params[:id], shop_id: current_shop.id)

  response.headers['Content-Type'] = 'text/event-stream'
  response.headers['Cache-Control'] = 'no-cache'
  response.headers['X-Accel-Buffering'] = 'no'  # Nginx: disable proxy buffering
  response.headers['Connection'] = 'keep-alive'

  # If already completed, send persisted steps + complete event, then close
  if run.completed? || run.failed?
    send_replay(run)
    return
  end

  # Stream live from Redis pub/sub
  redis = Redis.new(url: ENV.fetch('REDIS_URL'))
  begin
    # First, send any already-persisted steps (catch-up on reconnect)
    run.steps.each_with_index do |step, i|
      sse_write("step", step.merge("index" => i))
    end

    # Then subscribe to live events
    redis.subscribe("agent_stream:#{run.id}") do |on|
      on.message do |_channel, message|
        event = JSON.parse(message)
        sse_write(event["event"], event["data"])

        if event["event"] == "complete" || event["event"] == "error"
          redis.unsubscribe
        end
      end
    end
  rescue ActionController::Live::ClientDisconnected, IOError
    # Browser navigated away — clean up silently
  ensure
    redis.close
  end
end

private

def sse_write(event, data)
  response.stream.write("event: #{event}\ndata: #{data.to_json}\n\n")
end
```

**Critical: ActionController::Live.** The SSE endpoint must `include ActionController::Live` to get streaming response support. This is separate from ActionCable — it's just Rails' built-in streaming support.

#### 1.3.5 Streaming from the Agent (Sidekiq Job Modifications)

The existing `Agents::InventoryMonitor` has a `log()` method that appends to `@log` array. We modify it to also publish to Redis:

```ruby
class AgentStreamJob
  include Sidekiq::Job
  sidekiq_options queue: :default, retry: 2

  def perform(agent_run_id)
    run = AgentRun.find(agent_run_id)
    run.update!(status: 'running', started_at: Time.current)

    shop = Shop.active.find(run.shop_id)
    ActsAsTenant.with_tenant(shop) do
      agent = Agents::InventoryMonitor.new(
        shop,
        provider: run.provider,
        model: run.model,
        stream_callback: method(:publish_step).curry[run]
      )
      result = agent.run
      complete_run(run, result)
    end
  rescue StandardError => e
    fail_run(run, e)
  end

  private

  def publish_step(run, step_data)
    # Persist to DB (append to jsonb array)
    run.reload
    run.steps << step_data
    run.save!

    # Publish to Redis pub/sub for live listeners
    redis.publish("agent_stream:#{run.id}", {
      event: step_data[:event] || 'step',
      data: step_data
    }.to_json)
  end

  def complete_run(run, result)
    run.update!(
      status: 'completed',
      completed_at: Time.current,
      results: result,
      turns: result[:turns]
    )
    redis.publish("agent_stream:#{run.id}", {
      event: 'complete',
      data: result
    }.to_json)

    # Also update shop's last_agent_results for backward compat
    run.shop.update!(last_agent_run_at: Time.current, last_agent_results: result)
  end

  def fail_run(run, error)
    run&.update!(status: 'failed', completed_at: Time.current, error_message: error.message)
    redis.publish("agent_stream:#{run.id}", {
      event: 'error',
      data: { message: 'Agent run failed', error_class: error.class.name }
    }.to_json)
    Sentry.capture_exception(error) if defined?(Sentry)
  end

  def redis
    @redis ||= Redis.new(url: ENV.fetch('REDIS_URL'))
  end
end
```

**Modification to `Agents::InventoryMonitor`:** Accept optional `stream_callback` proc. In the `log()` method, if callback is present, call it with structured step data instead of just appending a string:

```ruby
def log(message, event: 'step')
  entry = "[#{Time.current.strftime('%H:%M:%S')}] #{sanitize_log(message)}"
  @log << entry

  if @stream_callback
    @stream_callback.call({
      event: event,
      index: @log.size - 1,
      timestamp: Time.current.iso8601,
      message: entry
    })
  end

  Rails.logger.info("[Agents::InventoryMonitor] #{entry}")
end
```

#### 1.3.6 LLM Streaming Differences

All three providers support streaming, but we are NOT streaming individual tokens. We are streaming agent-level steps (tool calls, tool results, summaries). Each LLM turn is a complete API call. The streaming here is at the orchestration layer, not the token layer.

If we later want token-level streaming (showing the AI "typing" its summary):

| Provider | Streaming API | Mechanism |
|----------|---------------|-----------|
| Anthropic | `client.messages(stream: true)` | Returns event stream with `content_block_delta` events containing text chunks |
| OpenAI | `client.chat(parameters: { stream: true })` | Returns chunks via `choices[0].delta.content` |
| Google | `streamGenerateContent` endpoint | Returns `candidates[0].content.parts[0].text` chunks |

**Decision for v1:** Agent-step-level streaming only. Token streaming is a v2 enhancement. Rationale: the valuable information is "what tool did the agent call" and "what did it find," not watching it type character by character. Token streaming would require modifying `LLM::Base` interface, handling partial tool call JSON, and adds significant complexity.

#### 1.3.7 Frontend (Vanilla JS EventSource)

```javascript
// agent-live-stream.js
(function() {
  "use strict";

  var runBtn = document.getElementById("agent-run-btn");
  var statusEl = document.getElementById("agent-status");
  if (!runBtn || !statusEl) return;

  var eventSource = null;
  var stepIndex = 0;

  runBtn.addEventListener("click", function(e) {
    e.preventDefault();
    runBtn.disabled = true;
    runBtn.textContent = "Analyzing\u2026";
    statusEl.innerHTML = '<div class="agent-stream-live" id="agent-stream-container"></div>';
    stepIndex = 0;

    // Get provider/model from select
    var sel = document.getElementById("agent-provider");
    var parts = (sel && sel.value) ? sel.value.split("|") : ["", ""];
    var provider = parts[0] || "";
    var model = parts[1] || "";

    // POST to start async run
    fetch("/agents/run_async", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').content
      },
      body: JSON.stringify({ provider: provider, model: model })
    })
    .then(function(resp) {
      if (resp.status === 409) {
        throw new Error("Agent already running");
      }
      if (!resp.ok) throw new Error("Failed to start agent");
      return resp.json();
    })
    .then(function(data) {
      connectStream(data.run_id);
    })
    .catch(function(err) {
      runBtn.disabled = false;
      runBtn.textContent = "Run Analysis";
      showError(err.message);
    });
  });

  function connectStream(runId) {
    if (eventSource) eventSource.close();

    eventSource = new EventSource("/agents/stream/" + runId);

    eventSource.addEventListener("step", function(e) {
      var data = JSON.parse(e.data);
      appendStep(data);
    });

    eventSource.addEventListener("tool_call", function(e) {
      var data = JSON.parse(e.data);
      appendStep(data, "tool");
    });

    eventSource.addEventListener("complete", function(e) {
      var data = JSON.parse(e.data);
      eventSource.close();
      eventSource = null;
      renderFinalResults(data);
      runBtn.disabled = false;
      runBtn.textContent = "Run Analysis";
    });

    eventSource.addEventListener("error", function(e) {
      // EventSource auto-reconnects on network errors.
      // On server-sent error event, close and show message.
      if (eventSource.readyState === EventSource.CLOSED) {
        runBtn.disabled = false;
        runBtn.textContent = "Run Analysis";
        showError("Connection lost. Check results on refresh.");
      }
    });
  }

  function appendStep(data, type) {
    var container = document.getElementById("agent-stream-container");
    if (!container) return;

    var entry = document.createElement("div");
    entry.className = "agent-log__entry agent-log__entry--reveal";
    if (type === "tool") entry.classList.add("agent-log__entry--tool");

    stepIndex++;
    entry.innerHTML =
      '<span class="agent-log__step">' + stepIndex + '</span>' +
      '<span class="agent-log__text">' + escapeHtml(data.message) + '</span>';
    container.appendChild(entry);
    entry.scrollIntoView({ behavior: "smooth", block: "end" });
  }

  function escapeHtml(str) {
    var div = document.createElement("div");
    div.textContent = str;
    return div.innerHTML;
  }

  function showError(msg) {
    statusEl.innerHTML = '<span class="bento__sub" style="color:var(--color-destructive)">' +
      escapeHtml(msg) + '</span>';
  }

  function renderFinalResults(data) {
    // Re-fetch the partial via HTMX to get server-rendered results
    // This keeps the rendering logic in ERB (single source of truth)
    if (window.htmx) {
      htmx.ajax("GET", "/agents/results_partial?run_id=" + (data.run_id || "latest"), {
        target: "#agent-status", swap: "innerHTML"
      });
    }
  }
})();
```

#### 1.3.8 Edge Cases and Failure Modes

**User navigates away mid-stream:**
- EventSource disconnects, `ActionController::Live::ClientDisconnected` is caught in the SSE controller, Redis subscription is cleaned up.
- The Sidekiq job continues to completion regardless (it doesn't know or care about SSE connections).
- Steps are persisted in the `agent_runs.steps` column.
- When the merchant returns to the dashboard, they see the completed results (from `shop.last_agent_results`).

**Connection drops and reconnects:**
- `EventSource` auto-reconnects with exponential backoff (built into the browser API).
- On reconnect, the SSE endpoint sends all persisted steps first (catch-up), then subscribes to Redis for live events.
- The `index` field on each step allows the frontend to deduplicate (skip steps it already rendered).

**Agent takes >30 seconds:**
- This is the primary reason for the async architecture. The initial POST returns in <100ms (just creates a record and enqueues). The SSE connection has no timeout because it's a streaming response.
- On Heroku/Railway: SSE connections are kept alive as long as data is sent within 55 seconds. The heartbeat mechanism (send a comment `:\n\n` every 15s) prevents proxy timeout.
- In the Sidekiq job, add heartbeat publishing: if no step is published for 10 seconds, publish a `{ event: "heartbeat" }` to keep the SSE connection alive.

**Multiple concurrent runs from same shop:**
- Prevented at the API level: 409 Conflict if a run is already pending/running.
- A "Cancel" button sets the AgentRun status to `cancelled`. The Sidekiq job checks `run.reload.cancelled?` between turns and exits early.

**Redis pub/sub reliability:**
- Redis pub/sub is fire-and-forget — if no one is subscribed, messages are lost. This is fine because the DB `steps` column is the source of truth.
- If Redis is down, the SSE endpoint falls back to polling the DB `steps` column every 2 seconds (degraded but functional).

**Memory pressure from open connections:**
- Each SSE connection holds one Puma thread. With Puma's default 5 threads per worker, 5 concurrent SSE connections per process saturate the thread pool.
- **Mitigation:** Use a dedicated Puma worker (or separate process) for SSE endpoints, or configure Puma with more threads for the streaming worker.
- **Realistic scale:** A shop has 1-3 merchants. Even with 1000 shops, not all run agents simultaneously. Peak concurrent SSE connections: ~50-100.
- **Alternative for scale:** If this becomes a bottleneck, extract SSE to a standalone Rack app using `async` (e.g., Falcon or Iodine server) that doesn't consume Puma threads. But premature for launch.

#### 1.3.9 CSP Implications

SSE connections are same-origin, so the existing CSP `connect-src 'self'` (if set) already allows them. No changes needed. The `frame-ancestors` directive for Shopify embedding is unrelated to SSE.

#### 1.3.10 Deployment Constraints

| Platform | SSE Support | Notes |
|----------|-------------|-------|
| Heroku | Yes, with caveats | 55-second idle timeout; heartbeats required every <55s. Standard dynos support SSE. |
| Railway | Yes | No hard idle timeout, but configure `--keepalive-timeout` in Puma |
| Render | Yes | 100s idle timeout by default; heartbeats every 30s recommended |
| Fly.io | Yes | Native support, no special config |
| Embedded Shopify iframe | Yes | SSE is just HTTP; no WebSocket upgrade needed |

#### 1.3.11 Backward Compatibility

The existing `POST /agents/run` synchronous endpoint remains for backward compat and for HTMX fallback. The new `run_async` + SSE is opt-in via the updated frontend JS. If JavaScript fails to load, the old HTMX flow still works.

#### 1.3.12 Files Modified/Created

```
NEW:
  app/models/agent_run.rb
  app/controllers/agents_controller.rb
  app/jobs/agent_stream_job.rb
  app/assets/javascripts/agent-live-stream.js
  db/migrate/XXXX_create_agent_runs.rb

MODIFIED:
  app/services/agents/inventory_monitor.rb  (add stream_callback)
  app/views/dashboard/index.html.erb        (wire up new JS)
  app/views/dashboard/_agent_results.html.erb (handle replay)
  config/routes.rb                          (add /agents/* routes)
```

#### 1.3.13 Performance Benchmarks

| Metric | Target |
|--------|--------|
| Time from click to first step appearing | <500ms |
| Step delivery latency (Redis pub to browser) | <100ms |
| Memory per SSE connection | <5KB |
| Max concurrent SSE connections per Puma worker | 5 (1 per thread) |
| Total agent run time (unchanged) | 5-30s depending on LLM |

#### 1.3.14 Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Puma thread exhaustion from SSE | Medium | High (blocks all requests) | Dedicated worker, thread pool monitoring, connection timeout (5 min max) |
| Redis pub/sub message loss | Low | Low (DB is source of truth) | Steps persisted before publishing |
| Agent run stuck (never completes) | Low | Medium | 5-minute timeout in Sidekiq, status watchdog job |
| Browser doesn't support EventSource | Very Low | Low | Fallback to sync HTMX flow; EventSource has 97%+ support |

#### 1.3.15 Estimated Effort

| Task | Effort |
|------|--------|
| Migration + AgentRun model | 15 min |
| AgentsController (run_async + SSE stream) | 45 min |
| AgentStreamJob + InventoryMonitor callback | 30 min |
| Frontend JS (EventSource + UI) | 30 min |
| Tests (model, controller, job) | 45 min |
| **Total** | **~3 hours Claude execution time** |

---

## 2. Predictive Stockout Timeline

### 2.1 Problem Statement

The dashboard shows *current* inventory state but gives no forward-looking signal. A merchant with 50 units of a hot product doesn't know if that's 2 days of stock or 2 months. The predictive stockout timeline turns static numbers into actionable timelines: "5 days until stockout" changes the merchant's urgency completely.

### 2.2 Architecture

```
  +------------------+     +---------------------+     +------------------+
  | InventorySnapshot|     | StockoutPrediction  |     | Dashboard /      |
  | (daily records)  |---->| Job (daily at 4 AM) |---->| Inventory views  |
  +------------------+     +---------------------+     +------------------+
                                    |
                           +--------v--------+
                           | stockout_       |
                           | predictions     |
                           | table           |
                           +-----------------+
```

### 2.3 Algorithm: Daily Sell Rate Calculation

The core algorithm computes sell rate from inventory snapshot deltas:

```
For variant V over the last N days:
  1. Gather snapshots ordered by snapshotted_at ASC
  2. For each consecutive pair (s1, s2):
     delta = s1.available - s2.available
     - If delta > 0: units sold = delta (stock decreased = sales)
     - If delta < 0: restock event (stock increased = ignore this interval)
     - If delta == 0: no sales in this interval
  3. daily_sell_rate = total_units_sold / total_sale_days
     (only count days where delta > 0 or delta == 0; exclude restock intervals)
  4. days_until_stockout = current_available / daily_sell_rate
```

**Why this works:** `inventory_snapshots` records `available` at each sync. The delta between consecutive snapshots represents net sales (minus restocks). By filtering out restock events (negative deltas), we isolate pure consumption rate.

**Pseudocode:**

```ruby
module Inventory
  class StockoutPredictor
    MIN_DATA_POINTS = 5          # Need at least 5 snapshots for any prediction
    HIGH_CONFIDENCE_POINTS = 14  # 14+ days = "predicted", <14 = "estimated"
    LOOKBACK_DAYS = 90           # Maximum history window
    SEASONAL_WINDOW = 7          # Rolling 7-day average for smoothing

    def initialize(shop)
      @shop = shop
    end

    def predict_all
      variants_with_snapshots.map { |v| predict_variant(v) }.compact
    end

    def predict_variant(variant)
      snapshots = fetch_snapshots(variant.id)
      return nil if snapshots.size < MIN_DATA_POINTS

      sell_rate = calculate_sell_rate(snapshots)
      return nil if sell_rate.nil? || sell_rate <= 0

      current_available = snapshots.last.available
      return zero_stock_result(variant) if current_available <= 0

      days_remaining = (current_available.to_f / sell_rate).round(1)
      confidence = determine_confidence(snapshots.size, sell_rate_variance(snapshots))

      {
        variant: variant,
        daily_sell_rate: sell_rate.round(2),
        days_remaining: days_remaining,
        predicted_stockout_date: Date.current + days_remaining.ceil.days,
        confidence: confidence,
        current_available: current_available,
        data_points: snapshots.size
      }
    end

    private

    def calculate_sell_rate(snapshots)
      sale_days = 0
      total_sold = 0

      snapshots.each_cons(2) do |s1, s2|
        delta = s1.available - s2.available
        if delta >= 0
          # Stock decreased or stayed same = sales (or zero sales)
          total_sold += delta
          sale_days += 1
        end
        # delta < 0 means restock — skip this interval
      end

      return nil if sale_days.zero?
      total_sold.to_f / sale_days
    end
  end
end
```

### 2.4 Handling Edge Cases

#### Products with irregular sales (seasonal, spiky)

Use a **weighted moving average** instead of simple average. Recent days weighted more heavily:

```ruby
def weighted_sell_rate(snapshots)
  deltas = extract_sale_deltas(snapshots)
  return nil if deltas.empty?

  # Exponential decay: recent days weighted 2x more than 30-day-old data
  total_weight = 0.0
  weighted_sum = 0.0

  deltas.each_with_index do |delta, i|
    age_days = deltas.size - 1 - i  # 0 = most recent
    weight = Math.exp(-0.03 * age_days) # ~50% weight at 23 days old
    weighted_sum += delta * weight
    total_weight += weight
  end

  weighted_sum / total_weight
end
```

#### New products with insufficient history

```ruby
def determine_confidence(data_points, variance)
  if data_points < MIN_DATA_POINTS
    :insufficient  # Don't show prediction at all
  elsif data_points < HIGH_CONFIDENCE_POINTS
    :estimated     # Show with "estimated" badge
  elsif variance > 0.5
    :estimated     # High variance = unreliable even with data
  else
    :predicted     # Show with "predicted" badge (high confidence)
  end
end
```

| Data Points | Variance | Label Shown |
|-------------|----------|-------------|
| < 5 | Any | "Insufficient data" (no prediction) |
| 5-13 | Any | "Estimated: ~X days" |
| 14+ | High (>0.5 CoV) | "Estimated: ~X days" |
| 14+ | Low (<=0.5 CoV) | "Predicted: X days" |

#### Products that get restocked mid-period

The algorithm already handles this: negative deltas (restocks) are excluded from the sell rate calculation. Only downward or flat movements count as "sale days."

```
Day 1: 100 available
Day 2: 85 available   → delta = +15 (sold 15)
Day 3: 80 available   → delta = +5  (sold 5)
Day 4: 200 available  → delta = -120 (RESTOCK — excluded)
Day 5: 185 available  → delta = +15 (sold 15)

Sell rate = (15 + 5 + 15) / 3 sale days = 11.67/day
(Day 4 excluded entirely)
```

#### Products with zero sales

If `daily_sell_rate == 0` for all observed days, the prediction is "No stockout predicted" (infinite days). Show as green with no countdown. Do NOT show "Infinity days" — show "Stable (no recent sales)."

#### Products that just went to zero

Retroactive calculation: use the last N snapshots before reaching zero to calculate what the sell rate *was*:

```ruby
def zero_stock_result(variant)
  {
    variant: variant,
    daily_sell_rate: calculate_sell_rate(fetch_snapshots(variant.id))&.round(2),
    days_remaining: 0,
    predicted_stockout_date: Date.current, # Already stocked out
    confidence: :actual,
    current_available: 0,
    status: :stocked_out
  }
end
```

#### Multi-variant products

**Per-variant predictions.** Each variant (S, M, L, XL of the same tee) has different sell rates. The inventory page shows per-variant predictions. The product-level summary shows the **worst-case variant** ("Organic Cotton Tee — Size M stocks out in 3 days").

### 2.5 Database Schema

```ruby
# Migration: create_stockout_predictions
create_table :stockout_predictions do |t|
  t.bigint :shop_id, null: false
  t.bigint :variant_id, null: false
  t.float :daily_sell_rate                           # units/day
  t.float :days_remaining                            # days until zero
  t.date :predicted_stockout_date                    # sell_rate projected forward
  t.string :confidence, null: false, default: 'estimated'  # insufficient, estimated, predicted, actual
  t.integer :current_available, null: false, default: 0
  t.integer :data_points, null: false, default: 0    # snapshot count used
  t.float :sell_rate_variance                        # coefficient of variation
  t.datetime :calculated_at, null: false
  t.timestamps

  t.index [:shop_id, :variant_id], unique: true, name: 'idx_predictions_shop_variant'
  t.index [:shop_id, :days_remaining], name: 'idx_predictions_shop_days'
  t.index [:shop_id, :predicted_stockout_date], name: 'idx_predictions_shop_date'
end
add_foreign_key :stockout_predictions, :shops, on_delete: :cascade
add_foreign_key :stockout_predictions, :variants, on_delete: :cascade
```

**Why a table, not computed on the fly?** Computing sell rates for 1000 variants requires joining against `inventory_snapshots` (potentially 90 * 1000 = 90,000 rows). This is a 200-500ms query. Caching in a table with a daily refresh means the dashboard reads from a simple indexed table (sub-10ms).

**Unique constraint on (shop_id, variant_id):** Each variant has exactly one prediction. The daily job `UPSERT`s (insert or update) rather than delete-and-recreate, preserving the row ID for any foreign key references.

### 2.6 Background Job

```ruby
class StockoutPredictionJob < ApplicationJob
  queue_as :low

  def perform(shop_id = nil)
    if shop_id
      predict_for_shop(Shop.active.find(shop_id))
    else
      Shop.active.find_each { |shop| predict_for_shop(shop) }
    end
  end

  private

  def predict_for_shop(shop)
    ActsAsTenant.with_tenant(shop) do
      predictor = Inventory::StockoutPredictor.new(shop)
      predictions = predictor.predict_all

      # Upsert all predictions in a single bulk operation
      StockoutPrediction.upsert_all(
        predictions.map { |p| prediction_attrs(shop, p) },
        unique_by: :idx_predictions_shop_variant,
        update_only: %i[daily_sell_rate days_remaining predicted_stockout_date
                        confidence current_available data_points sell_rate_variance calculated_at]
      )

      # Clean up predictions for variants that no longer exist
      active_variant_ids = predictions.map { |p| p[:variant].id }
      StockoutPrediction.where(shop_id: shop.id)
                         .where.not(variant_id: active_variant_ids)
                         .delete_all
    end
  rescue StandardError => e
    Rails.logger.error("[StockoutPredictionJob] Error for shop #{shop.id}: #{e.message}")
    Sentry.capture_exception(e) if defined?(Sentry)
  end
end
```

**Schedule:** Daily at 4:00 AM UTC via `sidekiq-cron`. Also triggered after any `InventorySyncJob` completes (to update predictions when fresh snapshot data arrives).

### 2.7 Query Performance at Scale

**Scenario: 10,000 variants with 90 days of daily snapshots = 900,000 snapshot rows per shop.**

The critical query is fetching snapshots per variant for the last 90 days:

```sql
SELECT variant_id, available, snapshotted_at
FROM inventory_snapshots
WHERE shop_id = ? AND snapshotted_at > (NOW() - INTERVAL '90 days')
ORDER BY variant_id, snapshotted_at ASC
```

This query uses `idx_snapshots_shop_time` index. For 900K rows, estimated execution time: 200-400ms with index scan.

**Optimization: batch processing.** Process variants in batches of 100 to avoid loading all 900K rows into memory:

```ruby
def predict_all
  predictions = []
  Variant.joins(:product)
         .where(products: { deleted_at: nil })
         .find_each(batch_size: 100) do |variant|
    result = predict_variant(variant)
    predictions << result if result
  end
  predictions
end
```

**At 100K SKUs:** The snapshot table would have ~9M rows per shop. At this scale:
1. Partition `inventory_snapshots` by `snapshotted_at` (monthly range partitions)
2. Add a materialized view for daily aggregates per variant
3. Run predictions in parallel using Sidekiq batches (100 variants per job)

**For launch (targeting <10K SKUs):** The simple approach works. Add monitoring to track prediction job duration and alert if >60s.

### 2.8 Caching Strategy

```
Level 1: Database table (StockoutPrediction) — refreshed daily
Level 2: Rails cache — per-shop predictions cached for 2 hours
Level 3: View fragment caching — individual variant prediction badges cached for 30 min
```

```ruby
# In controller/helper
def predictions_for_shop
  Rails.cache.fetch("shop:#{current_shop.id}:stockout_predictions", expires_in: 2.hours) do
    StockoutPrediction.where(shop_id: current_shop.id)
                       .includes(variant: :product)
                       .order(:days_remaining)
                       .to_a
  end
end
```

**Cache invalidation:** When `InventorySyncJob` runs (new snapshot data), clear the predictions cache. When `StockoutPredictionJob` runs, the cache naturally expires.

**When merchant manually adjusts inventory:** This creates a new snapshot through the Shopify webhook pipeline (`products/update` webhook). The next prediction job run will incorporate the new data. For immediate feedback, trigger a per-variant re-prediction on demand:

```ruby
# POST /inventory/:id/refresh_prediction
def refresh_prediction
  variant = Variant.find(params[:id])
  prediction = Inventory::StockoutPredictor.new(current_shop).predict_variant(variant)
  # Update the cached prediction
  StockoutPrediction.upsert(prediction_attrs(current_shop, prediction),
                             unique_by: :idx_predictions_shop_variant)
  # Return updated badge HTML via HTMX
end
```

### 2.9 Integration with Alerts and Supplier Lead Times

The killer insight: **compare days_remaining with supplier lead_time_days.**

```ruby
def urgency_status(prediction, variant)
  return :stocked_out if prediction.current_available <= 0
  return :safe if prediction.days_remaining > 30

  lead_time = variant.supplier&.lead_time_days || 14

  if prediction.days_remaining <= lead_time
    :order_now   # "Stockout in 5 days, supplier lead time 14 days — ORDER NOW"
  elsif prediction.days_remaining <= lead_time * 1.5
    :order_soon  # "Stockout in 18 days, lead time 14 days — order this week"
  elsif prediction.days_remaining <= 14
    :warning     # General low-stock warning
  else
    :healthy
  end
end
```

**Proactive alert integration:** When `StockoutPredictionJob` finds variants where `days_remaining <= supplier.lead_time_days` AND no alert has been sent this week for that variant, automatically create a "proactive_stockout" alert:

```ruby
def create_proactive_alerts(shop, predictions)
  predictions.each do |pred|
    next unless pred[:days_remaining]
    lead_time = pred[:variant].supplier&.lead_time_days || 14
    next unless pred[:days_remaining] <= lead_time
    next if recent_proactive_alert?(pred[:variant])

    Alert.create!(
      shop: shop, variant: pred[:variant],
      alert_type: 'proactive_stockout',
      channel: 'email', status: 'active',
      threshold: pred[:variant].low_stock_threshold || shop.low_stock_threshold,
      current_quantity: pred[:current_available],
      metadata: {
        days_remaining: pred[:days_remaining],
        daily_sell_rate: pred[:daily_sell_rate],
        supplier_lead_time: lead_time,
        predicted_stockout_date: pred[:predicted_stockout_date]
      }
    )
  end
end
```

### 2.10 UI Design

#### Dashboard Badge (on each variant row in /inventory)

```
+-----------------------------------------------+
| Organic Cotton Tee — Size M                   |
| Available: 23  |  Sell rate: 4.6/day          |
| [==========-------]  5 days  (predicted)       |
|         ^amber progress bar                    |
| "Lead time 14 days — ORDER NOW"               |
+-----------------------------------------------+
```

Color coding for the countdown badge:

| Days Remaining | Color | Badge |
|----------------|-------|-------|
| > 30 | Green (`#34C759` text on white) | "30+ days" |
| 14-30 | Default grey | "X days" |
| 7-14 | Amber (`#FFA500` text, amber border) | "X days — order soon" |
| 3-7 | Red (`#D72C0D` text) | "X days — order now" |
| 0-3 | Red + pulsing dot | "X days — URGENT" |
| 0 | Red + solid | "Stocked out" |
| Insufficient data | Grey, muted | "Insufficient data" |

**Accessibility:** Color is never the sole indicator. Each urgency level has a text label ("ORDER NOW", "order soon"). The progress bar has `aria-valuenow` and `aria-label` attributes.

#### Dashboard KPI Card

New dashboard tile showing the "most urgent" predictions:

```
+---------------------------------+
| Stockout Predictions            |
| 3 items stock out this week     |
|                                 |
| Merino Beanie     2 days  [!]  |
| Cotton Tee (M)    5 days  [!]  |
| Denim Jacket (L)  8 days       |
|                                 |
| View all predictions ->         |
+---------------------------------+
```

### 2.11 Files Modified/Created

```
NEW:
  app/models/stockout_prediction.rb
  app/services/inventory/stockout_predictor.rb
  app/jobs/stockout_prediction_job.rb
  app/views/inventory/_prediction_badge.html.erb
  app/views/dashboard/_prediction_card.html.erb
  db/migrate/XXXX_create_stockout_predictions.rb

MODIFIED:
  app/controllers/inventory_controller.rb  (load predictions)
  app/controllers/dashboard_controller.rb  (load top predictions)
  app/views/dashboard/index.html.erb       (add prediction card)
  app/views/inventory/index.html.erb       (add prediction badges)
  config/sidekiq_cron.yml                  (schedule daily prediction job)
```

### 2.12 Performance Benchmarks

| Metric | Target |
|--------|--------|
| Prediction calculation for 1000 variants | <5 seconds |
| Prediction calculation for 10,000 variants | <30 seconds |
| Dashboard prediction card load time | <50ms (from cached table) |
| Inventory list with prediction badges | <100ms (join against predictions table) |

### 2.13 Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Inaccurate predictions from sparse data | High (early users) | Medium (wrong urgency) | Confidence labels, minimum data thresholds |
| Large snapshot tables slow down prediction job | Medium (at scale) | Medium | Batch processing, partitioning, materialized views |
| Predictions create alert fatigue | Medium | Medium | Throttle proactive alerts to 1/week per variant |
| Seasonal patterns mislead predictions | Medium | Low | Weighted moving average, longer lookback windows |

### 2.14 Estimated Effort

| Task | Effort |
|------|--------|
| Migration + model | 15 min |
| StockoutPredictor service (algorithm) | 45 min |
| StockoutPredictionJob | 20 min |
| Proactive alerts integration | 20 min |
| Dashboard + inventory UI changes | 30 min |
| Tests (algorithm edge cases, job) | 45 min |
| **Total** | **~3 hours Claude execution time** |

---

## 3. One-Click Reorder Flow

### 3.1 Problem Statement

Today, the flow is fragmented: the merchant sees low stock on the dashboard, navigates to purchase orders, clicks "Generate Draft," gets a single AI-generated email for one supplier, and has no way to send it. The gap between "this is low stock" and "a PO email is in my supplier's inbox" is 10+ clicks and a context switch to their email client.

### 3.2 Architecture

```
  Low Stock Alert / Inventory Row
           |
           v (click "Reorder")
  +---------------------+
  | ReorderController   |
  | #prepare            |
  | - Identify supplier |
  | - Calculate qtys    |
  | - AI draft email    |
  +---------------------+
           |
           v
  +---------------------+
  | Preview Modal       |
  | - Edit quantities   |
  | - Edit notes        |
  | - Edit delivery     |
  | - Preview email     |
  +---------------------+
           |
           v (click "Send to Supplier")
  +---------------------+
  | ReorderController   |
  | #send               |
  | - Create PO record  |
  | - Send via SendGrid |
  | - Audit log         |
  +---------------------+
           |
           v
  +---------------------+
  | Confirmation Toast  |
  | "PO #247 sent to    |
  |  Acme Corp"         |
  +---------------------+
```

### 3.3 The Three Clicks

**Click 1: "Reorder" button** — appears on:
- Low-stock variant rows in `/inventory`
- Alert rows in `/alerts`
- Prediction badges showing "ORDER NOW" urgency
- Dashboard "most urgent" prediction card

**Click 2: "Preview & Edit"** — shown in a modal/drawer:
- AI-generated email body (editable)
- Line items table with editable quantities
- Supplier info (name, email) — pre-filled from variant.supplier
- Expected delivery date (calculated from supplier.lead_time_days)
- Optional notes field
- Estimated total cost (sum of qty * unit_price)

**Click 3: "Send to Supplier"** — fires the email and creates the PO record.

### 3.4 Detailed Design

#### 3.4.1 Reorder Preparation (Click 1 -> Click 2)

When the merchant clicks "Reorder" on a variant, we need to:

1. **Identify all low-stock variants from the same supplier.** If the merchant clicks "Reorder" on Variant A from Acme Corp, and Variants B and C from Acme Corp are also low, batch them into one PO.

2. **Calculate suggested quantities.** Formula: `qty = max(threshold * 2 - current_available, threshold)`. This targets 2x the threshold as the reorder point.

3. **Generate AI email draft.** Use existing `AI::PoDraftGenerator` (already works).

```ruby
class ReordersController < ApplicationController
  # GET /reorders/prepare?variant_id=123
  # or GET /reorders/prepare?supplier_id=456
  def prepare
    supplier, variants = resolve_reorder_targets
    return render_no_supplier_error unless supplier&.email.present?

    line_items = build_line_items(variants)
    draft_body = generate_draft(supplier, line_items)

    if request.headers['HX-Request']
      render partial: 'reorder_modal', locals: {
        supplier: supplier,
        line_items: line_items,
        draft_body: draft_body,
        expected_delivery: expected_delivery_date(supplier),
        estimated_total: line_items.sum { |li| li[:qty] * (li[:unit_price] || 0) }
      }
    else
      redirect_to inventory_path, alert: 'Enable JavaScript for reorder flow'
    end
  end

  # POST /reorders/send
  def send_order
    supplier = Supplier.find(reorder_params[:supplier_id])
    return render_no_email_error unless supplier.email.present?

    po = create_purchase_order(supplier)
    send_po_email(po, supplier)

    AuditLog.record(action: 'po_sent', shop: current_shop, request: request,
                    metadata: { purchase_order_id: po.id, supplier_id: supplier.id })

    if request.headers['HX-Request']
      render partial: 'reorder_confirmation', locals: { po: po, supplier: supplier }
    else
      redirect_to purchase_order_path(po), notice: "PO ##{po.po_number} sent to #{supplier.name}"
    end
  rescue StandardError => e
    handle_send_error(e)
  end

  private

  def resolve_reorder_targets
    if params[:variant_id]
      variant = Variant.includes(:supplier).find(params[:variant_id])
      supplier = variant.supplier
      # Find all low-stock variants from same supplier
      variants = supplier ? low_stock_for_supplier(supplier) : [variant]
      [supplier, variants]
    elsif params[:supplier_id]
      supplier = Supplier.find(params[:supplier_id])
      [supplier, low_stock_for_supplier(supplier)]
    else
      [nil, []]
    end
  end

  def low_stock_for_supplier(supplier)
    flagged = Inventory::LowStockDetector.new(current_shop).detect
    flagged.select { |fv| fv[:variant].supplier_id == supplier.id }
  end

  def build_line_items(variants)
    variants.map do |fv|
      v = fv.is_a?(Hash) ? fv[:variant] : fv
      available = fv.is_a?(Hash) ? fv[:available] : 0
      threshold = fv.is_a?(Hash) ? fv[:threshold] : (v.low_stock_threshold || current_shop.low_stock_threshold)
      qty = [threshold * 2 - available, threshold].max

      { variant_id: v.id, sku: v.sku, title: "#{v.product.title} — #{v.title}",
        qty: qty, unit_price: v.price || 0, available: available, threshold: threshold }
    end
  end
end
```

#### 3.4.2 PO Number Generation

Sequential per shop, formatted as `PO-{SHOP_ID}-{SEQ}`:

```ruby
class PurchaseOrder < ApplicationRecord
  before_validation :generate_po_number, on: :create

  private

  def generate_po_number
    return if po_number.present?

    max_seq = PurchaseOrder.where(shop_id: shop_id)
                            .where("po_number LIKE ?", "PO-#{shop_id}-%")
                            .maximum("CAST(SPLIT_PART(po_number, '-', 3) AS INTEGER)")
    next_seq = (max_seq || 0) + 1
    self.po_number = "PO-#{shop_id}-#{next_seq.to_s.rjust(4, '0')}"
  end
end
```

**Race condition prevention:** Use a database advisory lock when generating PO numbers, or use a sequence:

```ruby
# Better approach: database sequence per shop
# Store last_po_number in shops.settings jsonb
def generate_po_number
  return if po_number.present?

  shop.with_lock do
    current = shop.settings['last_po_number'] || 0
    next_num = current + 1
    shop.update!(settings: shop.settings.merge('last_po_number' => next_num))
    self.po_number = format('PO-%d-%04d', shop_id, next_num)
  end
end
```

#### 3.4.3 Email Sending via SendGrid

```ruby
class ReorderMailer < ApplicationMailer
  def purchase_order(po, supplier, custom_body)
    @po = po
    @supplier = supplier
    @custom_body = custom_body
    @line_items = po.line_items.includes(variant: :product)

    mail(
      to: supplier.email,
      subject: "Purchase Order #{po.po_number} from #{po.shop.shop_domain}",
      reply_to: po.shop.alert_email || "noreply@stockpilot.app"
    )
  end
end
```

**Email template:** HTML with plain text fallback. The HTML email uses inline styles (email client compatibility), white background, grey borders — consistent with the White & Grey design system. Includes:
- PO number and date
- Line items table (SKU, description, qty, unit price, line total)
- Grand total
- Expected delivery date
- Custom notes
- "Please confirm receipt of this order" call to action

**PDF attachment (v2):** Generate a PDF PO using Prawn gem. For v1, the email body IS the PO — keeps scope small.

#### 3.4.4 SendGrid Failure Handling

```ruby
def send_po_email(po, supplier)
  # Create PO record BEFORE sending email (PO exists even if email fails)
  po.update!(status: 'sending')

  begin
    ReorderMailer.purchase_order(po, supplier, reorder_params[:body]).deliver_now
    po.update!(status: 'sent', sent_at: Time.current)
  rescue StandardError => e
    po.update!(status: 'send_failed')
    Rails.logger.error("[Reorder] Email send failed for PO #{po.id}: #{e.message}")
    Sentry.capture_exception(e) if defined?(Sentry)
    raise # Re-raise so controller can show error
  end
end
```

**Why create PO before email:** If the email fails, the merchant sees "PO #247 — send failed" and can retry. If we only create the PO after email succeeds, a transient SendGrid error means the merchant has to redo the entire flow.

**New PO statuses:** `draft` -> `sending` -> `sent` -> `received` / `send_failed` -> `cancelled`

**Retry:** If status is `send_failed`, show a "Retry Send" button on the PO detail page. This re-sends the same email without regenerating the AI draft.

**Bounce handling (v2):** Configure SendGrid webhooks to POST to `/webhooks/sendgrid`. On `bounce` or `dropped` events, update PO status to `bounced` and notify the merchant. This requires:
1. SendGrid event webhook configuration (dashboard setup)
2. A new webhook endpoint with HMAC verification
3. PO status update logic

For v1, skip bounce handling. The merchant will know if the supplier didn't receive it.

#### 3.4.5 Idempotency

**Problem:** Double-click on "Send to Supplier" could send two emails.

**Solution:** Idempotency token in the form:

```ruby
# In the modal form
<input type="hidden" name="idempotency_key" value="<%= SecureRandom.uuid %>">

# In the controller
def send_order
  if PurchaseOrder.exists?(shop_id: current_shop.id,
                            metadata: { idempotency_key: reorder_params[:idempotency_key] })
    return render json: { error: 'Order already sent' }, status: :conflict
  end
  # ... proceed
end
```

Simpler alternative: disable the button client-side after first click, and check `po.status != 'draft'` server-side.

#### 3.4.6 Batching Multiple Low-Stock Items from Same Supplier

Already handled in `resolve_reorder_targets`: when the merchant clicks "Reorder" on any variant, we find ALL low-stock variants from the same supplier and include them in the PO.

The preview modal shows all items with individual quantity editors. The merchant can remove items they don't want to reorder (uncheck a checkbox per line item).

#### 3.4.7 Rate Limiting

Prevent accidentally sending 50 POs in one minute:

```ruby
# In ReordersController
before_action :check_reorder_rate_limit, only: [:send_order]

def check_reorder_rate_limit
  key = "reorder_rate:#{current_shop.id}"
  count = Rails.cache.increment(key, 1, expires_in: 1.minute)
  Rails.cache.write(key, 1, expires_in: 1.minute) if count.nil?

  if count && count > 5
    render json: { error: 'Too many orders. Wait a moment.' }, status: :too_many_requests
  end
end
```

#### 3.4.8 What If Supplier Has No Email?

```ruby
def render_no_supplier_error
  render partial: 'reorder_error', locals: {
    title: 'No supplier assigned',
    message: 'This variant has no supplier. Assign a supplier first.',
    action_url: suppliers_path,
    action_label: 'Manage Suppliers'
  }
end

def render_no_email_error
  render partial: 'reorder_error', locals: {
    title: 'Supplier has no email',
    message: 'Add an email address to this supplier to send purchase orders.',
    action_url: supplier_path(supplier),
    action_label: 'Edit Supplier'
  }
end
```

#### 3.4.9 Currency Handling

All USD for v1. Store prices as `decimal(10,2)` (already in schema). Display with `number_to_currency`. The email shows totals in USD.

For international support (v2): add `currency` column to suppliers table, use the `money-rails` gem for currency-aware formatting.

#### 3.4.10 Mobile UX

The reorder modal becomes a full-screen bottom sheet on mobile (viewport width < 768px). The line items table scrolls horizontally if needed. The "Send" button is sticky at the bottom of the sheet.

```css
@media (max-width: 768px) {
  .reorder-modal {
    position: fixed;
    bottom: 0;
    left: 0;
    right: 0;
    max-height: 90vh;
    border-radius: 12px 12px 0 0;
  }
  .reorder-modal__actions {
    position: sticky;
    bottom: 0;
    background: var(--color-bg);
    padding: var(--space-4);
    border-top: 1px solid var(--color-stroke-light);
  }
}
```

### 3.5 API Endpoints

```ruby
# routes.rb additions
resources :reorders, only: [] do
  collection do
    get :prepare        # GET /reorders/prepare?variant_id=X or supplier_id=X
    post :send_order    # POST /reorders/send
  end
end
```

### 3.6 Files Modified/Created

```
NEW:
  app/controllers/reorders_controller.rb
  app/mailers/reorder_mailer.rb
  app/views/reorder_mailer/purchase_order.html.erb
  app/views/reorder_mailer/purchase_order.text.erb
  app/views/reorders/_reorder_modal.html.erb
  app/views/reorders/_reorder_confirmation.html.erb
  app/views/reorders/_reorder_error.html.erb
  app/assets/javascripts/reorder-flow.js

MODIFIED:
  app/models/purchase_order.rb              (PO number generation, new statuses)
  app/views/inventory/index.html.erb        (add Reorder buttons)
  app/views/alerts/index.html.erb           (add Reorder buttons)
  config/routes.rb                          (add /reorders/* routes)
```

### 3.7 Performance Benchmarks

| Metric | Target |
|--------|--------|
| Time from "Reorder" click to modal showing | <2s (includes AI draft generation) |
| AI draft generation (Anthropic) | 1-3s |
| Email send (SendGrid) | <1s |
| Total flow (3 clicks) | <10s end-to-end |

### 3.8 Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Accidental PO send (double click) | Medium | Medium (unwanted email to supplier) | Idempotency token, button disable, rate limit |
| AI generates bad email content | Low | Medium (unprofessional email) | Preview step is mandatory, merchant edits before sending |
| SendGrid deliverability issues | Low | Medium (PO never arrives) | Retry mechanism, "send_failed" status, manual retry |
| Supplier confused by automated emails | Medium | Low | Clear "from" address, professional template, PO number for reference |

### 3.9 Estimated Effort

| Task | Effort |
|------|--------|
| ReordersController (prepare + send) | 30 min |
| Reorder modal (ERB + JS) | 30 min |
| ReorderMailer + templates | 20 min |
| PO number generation + new statuses | 15 min |
| Reorder buttons in inventory/alerts views | 15 min |
| Rate limiting + idempotency | 15 min |
| Tests | 30 min |
| **Total** | **~2.5 hours Claude execution time** |

---

## 4. Competitive Demo Mode

### 4.1 Problem Statement

The current demo toggle (`demo-toggle.js`) is a client-side hack that swaps a few numbers on the dashboard. It doesn't populate sub-pages (inventory, alerts, suppliers, POs), doesn't persist across navigation, and looks obviously fake. For investor demos, Shopify App Store screenshots, and sales calls, we need a full-stack demo mode with realistic data that makes the app look like it's being used by a real, thriving store.

### 4.2 Architecture Decision: Seed Data with Session Flag

```
                     Options Considered
  +-------------------+-------------------+-------------------+
  | Separate Database | In-Memory Overlay | Seed + Session    |
  | (schema per mode) | (read interceptor)| Flag              |
  +-------------------+-------------------+-------------------+
  | REJECTED          | REJECTED          | SELECTED          |
  | Reason: massive   | Reason: every     | Reason: uses      |
  | infrastructure    | query needs       | existing models,  |
  | overhead, can't   | interception,     | real queries,     |
  | share migrations  | fragile, N+1      | full app works    |
  |                   | explosion         | exactly as real   |
  +-------------------+-------------------+-------------------+
```

**Decision: Dedicated demo shop with seeded data, activated via session flag.**

```
1. Rake task seeds a "demo shop" (shop_domain: "demo.myshopify.com")
2. Demo toggle sets session[:demo_mode] = true
3. ApplicationController switches tenant to demo shop when demo_mode active
4. All pages render with demo data — no special query logic needed
5. Demo mode banner shown at top of page
6. Toggle off: session cleared, back to real shop
```

**Why this works brilliantly:** Because `acts_as_tenant` scopes ALL queries to the current shop, switching the tenant to the demo shop means every single page — dashboard, inventory, alerts, suppliers, POs — automatically shows demo data. Zero special-casing in controllers or views.

### 4.3 Isolation Guarantee

**Demo data can NEVER leak into real shop data because:**

1. `acts_as_tenant :shop` is on every model. Demo data belongs to `shop_id = demo_shop.id`.
2. Real shops have `shop_domain` matching `*.myshopify.com` (validated by regex). Demo shop uses `demo.myshopify.com` which is not a real Shopify domain.
3. Demo mode only changes the tenant — it doesn't modify any data. The demo shop's data is read-only in practice (no sync jobs, no webhooks point to it).
4. The demo shop has `access_token: "demo_token_not_real"` and `uninstalled_at: nil`. Even if someone tried to use it as a real shop, all Shopify API calls would fail.

**Additional safety:** In `ApplicationController`, when demo mode is active, disable all write actions except toggling demo mode off:

```ruby
before_action :enforce_demo_read_only, if: :demo_mode?

def enforce_demo_read_only
  return if request.get? || request.head?
  return if controller_name == 'dashboard' && action_name == 'toggle_demo'

  # Allow agent runs in demo mode (read-only operation that generates insights)
  return if controller_name == 'agents' || controller_name == 'dashboard' && action_name == 'run_agent'

  redirect_to dashboard_path, alert: 'Demo mode is read-only'
end
```

### 4.4 Data Generation (Rake Task)

```ruby
# lib/tasks/demo_seed.rake
namespace :demo do
  desc 'Seed demo shop with realistic inventory data'
  task seed: :environment do
    DemoSeeder.new.seed!
  end

  desc 'Reset demo data (destroy and re-seed)'
  task reset: :environment do
    DemoSeeder.new.reset!
  end
end
```

#### 4.4.1 Product Categories and Realistic Data

```ruby
class DemoSeeder
  CATEGORIES = {
    apparel: {
      products: [
        { title: 'Organic Cotton Tee', type: 'Tops', vendor: 'EcoThread Co', price_range: 28..45,
          variants: ['XS', 'S', 'M', 'L', 'XL', '2XL'] },
        { title: 'Recycled Denim Jacket', type: 'Outerwear', vendor: 'BlueLoop Denim', price_range: 89..129,
          variants: ['S', 'M', 'L', 'XL'] },
        { title: 'Merino Wool Beanie', type: 'Accessories', vendor: 'Highland Knits', price_range: 24..32,
          variants: ['One Size'] },
        { title: 'Linen Button-Down', type: 'Tops', vendor: 'EcoThread Co', price_range: 55..75,
          variants: ['S', 'M', 'L', 'XL'] },
        { title: 'Hemp Canvas Sneakers', type: 'Footwear', vendor: 'Barefoot Supply', price_range: 79..110,
          variants: ['7', '8', '9', '10', '11', '12'] },
        # ... 40+ more products
      ],
      stock_profiles: {
        healthy: { range: 50..200, pct: 0.60 },
        low:     { range: 2..9,    pct: 0.25 },
        out:     { range: 0..0,    pct: 0.10 },
        trending_down: { range: 15..30, pct: 0.05 }
      }
    },
    electronics: {
      products: [
        { title: 'Bamboo Wireless Charger', type: 'Accessories', vendor: 'GreenTech Labs', price_range: 35..55,
          variants: ['Black', 'Natural', 'Walnut'] },
        { title: 'Solar Power Bank 10000mAh', type: 'Power', vendor: 'SunVolt', price_range: 45..65,
          variants: ['Black', 'White', 'Green'] },
        # ... 20+ more
      ]
    },
    food_bev: {
      products: [
        { title: 'Single Origin Coffee Beans', type: 'Coffee', vendor: 'Mountain Roast', price_range: 16..24,
          variants: ['250g', '500g', '1kg'] },
        { title: 'Organic Matcha Powder', type: 'Tea', vendor: 'Kyoto Harvest', price_range: 28..42,
          variants: ['30g Tin', '100g Bag'] },
        # ... 15+ more
      ]
    }
  }.freeze
end
```

**Target: 150 products, ~500 variants.** Enough to look like a real mid-market store without overwhelming the demo.

#### 4.4.2 Realistic Stock Patterns

For each variant, assign a stock profile that creates a realistic story:

```ruby
def assign_stock_level(variant, profile)
  case profile
  when :healthy
    rand(50..200)
  when :low
    rand(2..9)
  when :out
    0
  when :trending_down
    # Start high, decrease over 30 days
    start = rand(80..150)
    daily_decrease = rand(2..5)
    [start - (daily_decrease * 30), 0].max
  end
end
```

#### 4.4.3 Snapshot History (30 Days)

Generate 30 days of daily snapshots for each variant, creating realistic sell-through patterns:

```ruby
def generate_snapshots(variant, initial_stock, daily_sell_rate)
  30.downto(0).each do |days_ago|
    date = days_ago.days.ago
    sold_today = (daily_sell_rate * rand(0.5..1.5)).round  # variance
    available = [initial_stock - (sold_today * (30 - days_ago)), 0].max

    # Simulate a restock event around day 15 for some variants
    if days_ago == 15 && rand < 0.3
      available += rand(50..100)
    end

    InventorySnapshot.create!(
      shop: demo_shop, variant: variant,
      available: available, on_hand: available + rand(0..5),
      committed: rand(0..3), incoming: rand(0..10),
      snapshotted_at: date, created_at: date
    )
  end
end
```

#### 4.4.4 Supplier Data

```ruby
SUPPLIERS = [
  { name: 'EcoThread Co', email: 'orders@ecothread.co', contact: 'Sarah Chen', lead_time: 14, rating: 5 },
  { name: 'BlueLoop Denim', email: 'supply@blueloop.com', contact: 'Marcus Rivera', lead_time: 21, rating: 4 },
  { name: 'Highland Knits', email: 'wholesale@highlandknits.uk', contact: 'Fiona MacLeod', lead_time: 10, rating: 5 },
  { name: 'GreenTech Labs', email: 'b2b@greentech.io', contact: 'James Park', lead_time: 7, rating: 3 },
  { name: 'Barefoot Supply', email: 'orders@barefoot.supply', contact: 'Ana Ferreira', lead_time: 18, rating: 4 },
  { name: 'Mountain Roast', email: 'wholesale@mountainroast.co', contact: 'David Okafor', lead_time: 5, rating: 5 },
  { name: 'Kyoto Harvest', email: 'export@kyotoharvest.jp', contact: 'Yuki Tanaka', lead_time: 30, rating: 4 },
  { name: 'SunVolt', email: 'partners@sunvolt.tech', contact: 'Li Wei', lead_time: 14, rating: 3 }
]
```

#### 4.4.5 Alert History

```ruby
def generate_alerts
  # Mix of alerts from the last 7 days
  low_stock_variants.each do |variant|
    rand(1..3).times do
      Alert.create!(
        shop: demo_shop, variant: variant,
        alert_type: ['low_stock', 'out_of_stock'].sample,
        channel: 'email', status: ['active', 'active', 'dismissed'].sample,
        threshold: variant.low_stock_threshold || 10,
        current_quantity: rand(0..8),
        triggered_at: rand(7).days.ago + rand(24).hours,
        dismissed: [false, false, true].sample
      )
    end
  end
end
```

#### 4.4.6 Purchase Orders

```ruby
def generate_purchase_orders
  # 3 draft POs (waiting to be sent)
  # 5 sent POs (in transit)
  # 8 received POs (completed history)

  SUPPLIERS.sample(6).each_with_index do |s_data, i|
    supplier = Supplier.find_by(shop: demo_shop, name: s_data[:name])
    status = case i
             when 0..1 then 'draft'
             when 2..3 then 'sent'
             else 'received'
             end

    po = PurchaseOrder.create!(
      shop: demo_shop, supplier: supplier,
      status: status,
      order_date: rand(30).days.ago.to_date,
      expected_delivery: rand(14..30).days.from_now.to_date,
      sent_at: status == 'sent' ? rand(14).days.ago : nil
    )

    # 2-5 line items per PO
    supplier.variants.where(shop: demo_shop).sample(rand(2..5)).each do |v|
      PurchaseOrderLineItem.create!(
        purchase_order: po, variant: v,
        sku: v.sku, title: v.title,
        qty_ordered: rand(20..100),
        qty_received: status == 'received' ? rand(20..100) : 0,
        unit_price: v.price || rand(10..50)
      )
    end
  end
end
```

#### 4.4.7 AI Insights (Pre-generated)

Store pre-generated AI insights in the demo shop's cache so the dashboard doesn't need a real API key:

```ruby
def seed_ai_insights
  insights = <<~INSIGHTS
    - **Organic Cotton Tee (Size M)** is your fastest-selling variant at 4.6 units/day. At current stock (23 units), you'll be out in 5 days. Recommended: reorder 50 units from EcoThread Co today.
    - **Electronics category** is outperforming apparel by 23% this month. Consider expanding the Bamboo Wireless Charger line with new colorways.
    - **Highland Knits** has the best on-time delivery rate (98%) among your suppliers. Consider consolidating more accessories orders with them.
    - **3 variants** hit zero stock this week, resulting in an estimated $1,240 in lost revenue based on average daily sales.
    - Your overall inventory health is 72%. Target: above 85% by maintaining 2-week buffer stock on all variants with >2 units/day sell rate.
  INSIGHTS

  Rails.cache.write("shop:#{demo_shop.id}:ai_insights", insights, expires_in: 30.days)
end
```

### 4.5 Toggle Mechanism

```ruby
# In DashboardController or ApplicationController
def toggle_demo
  if session[:demo_mode]
    session.delete(:demo_mode)
    redirect_to dashboard_path, notice: 'Demo mode off'
  else
    demo_shop = Shop.find_by(shop_domain: 'demo.myshopify.com')
    unless demo_shop
      redirect_to dashboard_path, alert: 'Demo data not seeded. Run: rails demo:seed'
      return
    end
    session[:demo_mode] = true
    redirect_to dashboard_path, notice: 'Demo mode on'
  end
end
```

```ruby
# In ApplicationController
def set_tenant
  if session[:demo_mode] && (demo = Shop.find_by(shop_domain: 'demo.myshopify.com'))
    ActsAsTenant.current_tenant = demo
  else
    ActsAsTenant.current_tenant = current_shop
  end
end
```

**Demo mode banner:** When `session[:demo_mode]` is active, render a sticky banner at the top:

```erb
<% if session[:demo_mode] %>
  <div class="demo-banner" role="alert">
    <span>Demo Mode</span>
    <span>Viewing sample data. <a href="/dashboard/toggle_demo" data-method="post">Exit demo</a></span>
  </div>
<% end %>
```

### 4.6 Investor Mode

Special data tuning for investor presentations. The seeder accepts a `--investor` flag that adjusts the data to highlight product strengths:

```ruby
# rails demo:seed INVESTOR=true
def investor_mode?
  ENV['INVESTOR'] == 'true'
end

def investor_adjustments
  return unless investor_mode?

  # More dramatic stockout predictions
  # Higher sell rates on key products
  # More AI-generated insights highlighting cost savings
  # Agent results showing "23 items flagged, 3 POs auto-drafted — saving ~4 hours/week"
  # Clear before/after story in the data
end
```

### 4.7 Performance

Generating 150 products + 500 variants + 15,000 snapshots (30 days * 500) + alerts + POs:

```ruby
# Estimated seed time:
# - 150 products: ~1s (bulk insert)
# - 500 variants: ~2s (bulk insert)
# - 15,000 snapshots: ~10s (bulk insert with insert_all)
# - Alerts, POs, line items: ~3s
# Total: ~16 seconds
```

Use `insert_all` for bulk operations to avoid 15,000 individual INSERTs:

```ruby
def generate_snapshots_bulk(variants_with_profiles)
  rows = []
  variants_with_profiles.each do |variant, profile|
    30.downto(0).each do |days_ago|
      rows << {
        shop_id: demo_shop.id, variant_id: variant.id,
        available: calculate_available(profile, days_ago),
        on_hand: ..., committed: ..., incoming: ...,
        snapshotted_at: days_ago.days.ago, created_at: days_ago.days.ago
      }
    end
  end
  InventorySnapshot.insert_all(rows)
end
```

### 4.8 Reset

```ruby
def reset!
  demo_shop = Shop.find_by(shop_domain: 'demo.myshopify.com')
  return unless demo_shop

  # Cascade delete handles everything (products, variants, snapshots, alerts, POs)
  demo_shop.destroy!

  # Re-seed
  seed!
end
```

### 4.9 Screenshots Optimization

For marketing screenshots, the demo data is designed to look compelling at specific viewport sizes:

- **Dashboard (1440x900):** All bento tiles filled with non-zero data, 3 recent alerts showing variety
- **Inventory list (1440x900):** Mix of green/amber/red status badges, predictions visible
- **Supplier page:** 8 suppliers with varying star ratings
- **PO detail:** A realistic PO with 4 line items, totaling ~$2,400

The seeder includes specific "hero" products that photograph well:
- Products with interesting names (not "Test Product 1")
- Varied price points ($16 coffee to $129 jacket)
- SKUs that look professional (ECO-CT-M, BLD-JK-L)

### 4.10 Files Modified/Created

```
NEW:
  lib/tasks/demo_seed.rake
  app/services/demo/seeder.rb
  app/services/demo/data_catalog.rb          (product/supplier definitions)
  app/views/layouts/_demo_banner.html.erb

MODIFIED:
  app/controllers/application_controller.rb  (demo tenant switching)
  app/controllers/dashboard_controller.rb    (toggle_demo action)
  app/views/layouts/application.html.erb     (render demo banner)
  config/routes.rb                           (add toggle_demo route)
```

### 4.11 Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Demo data leaks into real shop | Very Low | High | Tenant isolation via acts_as_tenant, separate shop record |
| Demo shop accidentally syncs with Shopify | Very Low | Low | Fake access token, no real shop_domain |
| Demo data looks unrealistic | Medium | Medium | Careful data design, real product names, realistic quantities |
| Seed task too slow | Low | Low | Bulk inserts, parallelize if needed |

### 4.12 Estimated Effort

| Task | Effort |
|------|--------|
| DemoSeeder service + data catalog | 45 min |
| Rake tasks (seed, reset) | 15 min |
| Toggle mechanism (session + tenant) | 20 min |
| Demo banner UI | 10 min |
| Read-only enforcement | 15 min |
| Tests (seeder, isolation) | 30 min |
| **Total** | **~2.5 hours Claude execution time** |

---

## 5. Implementation Order

```
         Phase 1                Phase 2              Phase 3
    +----------------+    +------------------+    +-----------+
    | Demo Mode      |    | Stockout         |    | Live Agent|
    | (foundation    |--->| Predictions      |--->| Stream    |
    | for demos)     |    | (core value)     |    | (polish)  |
    +----------------+    +------------------+    +-----------+
           |                      |                     |
           |                      v                     |
           |              +------------------+          |
           +----------->  | One-Click        |<---------+
                          | Reorder          |
                          | (depends on      |
                          | predictions)     |
                          +------------------+
                               Phase 2-3
```

### Recommended Order

| Order | Feature | Rationale |
|-------|---------|-----------|
| 1 | **Demo Mode** | Enables all other features to be demoed immediately. Low risk, high impact for investor calls. No new dependencies. |
| 2 | **Stockout Predictions** | Core intelligence value prop. Pure computation + DB, no external services. The "5 days until stockout" number is the centerpiece metric. |
| 3 | **One-Click Reorder** | Builds on predictions ("ORDER NOW" triggers the reorder flow). Requires SendGrid setup (external dependency). |
| 4 | **Live Agent Stream** | Polish feature. The agent already works — streaming makes it theatrical. Most complex (SSE, Redis pub/sub, concurrent connections). Save for last. |

### Dependency Graph

```
Demo Mode: no dependencies
Stockout Predictions: no dependencies (but demo mode makes it demo-able)
One-Click Reorder: soft dependency on predictions (for "ORDER NOW" trigger)
Live Agent Stream: no hard dependencies, but benefits from reorder (agent drafts POs -> stream shows it)
```

### Total Estimated Effort

| Feature | Effort |
|---------|--------|
| Demo Mode | ~2.5 hours |
| Stockout Predictions | ~3 hours |
| One-Click Reorder | ~2.5 hours |
| Live Agent Stream | ~3 hours |
| **Total** | **~11 hours Claude execution time** |

---

## 6. Cross-Cutting Concerns

### 6.1 Database Migrations Summary

```
1. create_agent_runs              (Live Agent Stream)
2. create_stockout_predictions    (Predictive Stockout)
3. add_sending_status_to_pos      (One-Click Reorder — adds 'sending', 'send_failed' to PO statuses)
```

No migration needed for Demo Mode (uses existing tables with a new shop record).

### 6.2 New Gems

```ruby
# None required for v1!
# - SSE: built into Rails (ActionController::Live)
# - Email: Rails ActionMailer (already configured)
# - JSON handling: built into Ruby
# - Bulk inserts: ActiveRecord insert_all (Rails 6+)
```

For v2 enhancements:
- `prawn` — PDF generation for PO attachments
- `money-rails` — multi-currency support
- `sendgrid-ruby` — webhook verification for bounce handling

### 6.3 Security Considerations

| Feature | Security Concern | Mitigation |
|---------|------------------|------------|
| Live Agent Stream | SSE endpoint auth | Verify shop_id matches session; scoped by tenant |
| Live Agent Stream | Redis channel sniffing | Channel names include run_id (UUID-ish); not guessable |
| Stockout Predictions | Data exposure | Predictions scoped by acts_as_tenant, same as all models |
| One-Click Reorder | Email injection | Supplier email validated by model; email body sanitized |
| One-Click Reorder | PO spam | Rate limiting (5/min per shop), idempotency tokens |
| Demo Mode | Data leakage | Tenant isolation; demo shop is a separate record; read-only enforcement |
| Demo Mode | Session hijacking | Demo flag is in server-side session, not a cookie value |

### 6.4 Testing Strategy

Each feature needs:
1. **Model specs** — validations, scopes, associations
2. **Service specs** — core logic (predictor algorithm, reorder preparation)
3. **Controller/request specs** — endpoint behavior, auth, error cases
4. **Job specs** — background job behavior, error handling
5. **Integration spec** — end-to-end flow (for reorder: click -> preview -> send -> PO created)

Estimated total test count: ~60-80 new examples across all four features.

### 6.5 Monitoring and Observability

Add Sentry breadcrumbs for:
- Agent stream connection opened/closed
- Prediction job duration per shop
- Reorder email sent/failed
- Demo mode toggled on/off

Add custom metrics (if Prometheus/StatsD configured):
- `agent_stream.connections.active` (gauge)
- `stockout_prediction.duration_seconds` (histogram)
- `reorder.emails_sent` (counter)
- `reorder.emails_failed` (counter)
