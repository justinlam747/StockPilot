# PRD: Event-Driven Architecture, Benchmarking & Agentic Testing Infrastructure

**Product:** Inventory Intelligence (StockPilot)
**Date:** 2026-03-17
**Status:** Draft — Awaiting Review
**Author:** Engineering

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [Problem Statement](#2-problem-statement)
3. [Architecture Overview](#3-architecture-overview)
4. [Event-Driven Architecture](#4-event-driven-architecture)
5. [Microservices Decomposition](#5-microservices-decomposition)
6. [API Documentation & Service Registry](#6-api-documentation--service-registry)
7. [Performance Benchmarking System](#7-performance-benchmarking-system)
8. [Agentic Testing Infrastructure](#8-agentic-testing-infrastructure)
9. [Developer Blog](#9-developer-blog)
10. [Testing Plan](#10-testing-plan)
11. [Autonomous Execution Contract](#11-autonomous-execution-contract)

---

## 1. Executive Summary

StockPilot currently operates as a monolithic Rails app with synchronous request-response flows. Webhooks arrive, get processed inline, and jobs fire sequentially. This works at low scale but creates invisible bottlenecks: we don't know how fast we actually process inventory updates end-to-end, we can't independently scale the AI agent pipeline vs. the webhook ingestion pipeline, and we have no proof of performance to show merchants or investors.

This PRD defines the transition to an **event-driven architecture** with clear service boundaries, a **real-time benchmarking system** that instruments every critical path with microsecond-precision timing, an **agentic testing framework** that autonomously validates the entire pipeline, and a **developer blog** documenting our engineering decisions publicly.

**Target state:** A merchant's inventory update webhook arrives → gets persisted → triggers low-stock detection → fires AI analysis → generates a purchase order draft → sends supplier email — all within **measurable, benchmarked, provable timeframes**.

---

## 2. Problem Statement

### What we can't do today

| Gap | Impact |
|-----|--------|
| No event bus — webhook processing is inline in the controller | Can't independently scale ingestion vs. processing; one slow handler blocks the entire webhook response |
| No timing instrumentation | We have zero data on how long any pipeline stage takes. "Fast" is a feeling, not a number |
| No service boundaries | The AI agent, inventory sync, alerting, and PO generation are all tangled in the same process. Can't deploy or scale independently |
| No API documentation | Merchants and partners have no reference for our endpoints. Internal devs context-switch to reading code |
| No benchmarking | Can't answer "how fast do we process an inventory update end-to-end?" with data |
| No agentic test harness | We test individual units but never test the full autonomous agent pipeline end-to-end under realistic conditions |
| No public engineering blog | No way to share technical decisions, attract engineering talent, or build credibility |

---

## 3. Architecture Overview

### Current State (Monolith)

```
Shopify Webhook → WebhooksController → Inline Processing → Sidekiq Job → Done
                  (synchronous)         (no timing)         (fire & forget)
```

### Target State (Event-Driven)

```
Shopify Webhook
    │
    ▼
┌─────────────────────┐
│  Ingestion Gateway   │ ← HMAC verify, parse, timestamp
│  (< 5ms response)    │
└─────────┬───────────┘
          │ publishes event
          ▼
┌─────────────────────┐     ┌──────────────────────┐
│   Event Bus (Redis   │────▶│  Inventory Service    │
│   Streams / Sidekiq) │     │  • Persist product     │
└─────────┬───────────┘     │  • Snapshot levels     │
          │                  │  • Detect low stock    │
          │                  └──────────┬─────────────┘
          │                             │ emits: inventory.low_stock_detected
          │                             ▼
          │                  ┌──────────────────────┐
          │                  │  Alerting Service      │
          │                  │  • Deduplicate          │
          │                  │  • Send notifications   │
          │                  └──────────┬─────────────┘
          │                             │ emits: alert.sent
          │                             ▼
          │                  ┌──────────────────────┐
          │                  │  AI Agent Service      │
          │                  │  • Analyze patterns     │
          │                  │  • Draft purchase orders│
          │                  │  • Generate insights    │
          │                  └──────────┬─────────────┘
          │                             │ emits: po.drafted, insights.generated
          │                             ▼
          │                  ┌──────────────────────┐
          │                  │  Notification Service  │
          │                  │  • Email supplier       │
          │                  │  • Slack webhook        │
          │                  │  • In-app notification  │
          │                  └────────────────────────┘
          │
          ▼
┌─────────────────────────────────────────────┐
│  Benchmark Collector (traces every stage)     │
│  • Ingestion latency                          │
│  • Processing latency                         │
│  • AI response time                           │
│  • End-to-end pipeline time                   │
│  • Stores in benchmark_traces table           │
└───────────────────────────────────────────────┘
```

---

## 4. Event-Driven Architecture

### 4.1 Event Bus

**Technology:** Redis Streams (already have Redis 7) with Sidekiq as the consumer framework.

**Why Redis Streams over Kafka/RabbitMQ:** We're a Shopify embedded app, not a distributed microservices platform. Redis Streams gives us ordered, persistent, consumer-group-based event streaming without adding infrastructure. It's already in our stack. When we outgrow it, the event interface stays the same — only the transport changes.

#### Event Schema

Every event follows a standard envelope:

```ruby
{
  event_id: SecureRandom.uuid,          # Idempotency key
  event_type: "inventory.updated",       # Dot-notation topic
  source: "ingestion_gateway",           # Which service emitted
  shop_id: 123,                          # Tenant scope
  occurred_at: Time.current.iso8601(6),  # Microsecond precision
  trace_id: SecureRandom.uuid,           # Correlation ID for benchmarking
  payload: { ... }                       # Event-specific data
}
```

#### Event Catalog

| Event Type | Source | Consumers | Description |
|---|---|---|---|
| `webhook.received` | Ingestion Gateway | Inventory Service | Raw Shopify webhook received and authenticated |
| `product.updated` | Inventory Service | Snapshot Service | Product/variant data persisted |
| `product.deleted` | Inventory Service | Snapshot Service | Product soft-deleted |
| `inventory.snapshot_created` | Snapshot Service | Low-Stock Detector | New inventory levels recorded |
| `inventory.low_stock_detected` | Low-Stock Detector | Alerting Service, AI Agent | Variant fell below threshold |
| `inventory.out_of_stock` | Low-Stock Detector | Alerting Service, AI Agent | Variant hit zero |
| `alert.created` | Alerting Service | Notification Service | New alert record created (deduplicated) |
| `alert.sent` | Notification Service | Benchmark Collector | Alert email/notification delivered |
| `agent.run_started` | AI Agent Service | Benchmark Collector | Agentic loop initiated |
| `agent.tool_called` | AI Agent Service | Benchmark Collector | Tool invocation within agent loop |
| `agent.run_completed` | AI Agent Service | Benchmark Collector | Agent finished all tool calls |
| `po.drafted` | AI Agent Service | Notification Service | Purchase order draft created |
| `po.sent` | Notification Service | Benchmark Collector | PO email sent to supplier |
| `insights.generated` | AI Agent Service | Dashboard Cache | AI insights ready for display |
| `sync.started` | Sync Orchestrator | Benchmark Collector | Full inventory sync begun |
| `sync.completed` | Sync Orchestrator | Benchmark Collector, Cache | Full sync finished |
| `benchmark.trace_completed` | Benchmark Collector | Dashboard | Full pipeline trace stored |

### 4.2 Event Publisher Module

```ruby
# app/services/events/publisher.rb
module Events
  class Publisher
    def self.publish(event_type, shop_id:, payload:, trace_id: nil)
      event = {
        event_id: SecureRandom.uuid,
        event_type: event_type,
        source: caller_locations(1, 1)[0].label,
        shop_id: shop_id,
        occurred_at: Time.current.iso8601(6),
        trace_id: trace_id || SecureRandom.uuid,
        payload: payload
      }

      # Persist to Redis Stream
      redis.xadd("stockpilot:events:#{event_type}", event)

      # Also dispatch via Sidekiq for consumer processing
      EventConsumerJob.perform_async(event.to_json)

      event
    end
  end
end
```

### 4.3 Event Consumer Pattern

```ruby
# app/jobs/event_consumer_job.rb
class EventConsumerJob < ApplicationJob
  def perform(event_json)
    event = JSON.parse(event_json, symbolize_names: true)
    router = Events::Router.new
    router.dispatch(event)
  end
end

# app/services/events/router.rb
module Events
  class Router
    HANDLERS = {
      "webhook.received"              => [Handlers::InventoryIngestor],
      "product.updated"               => [Handlers::SnapshotTrigger],
      "inventory.snapshot_created"     => [Handlers::LowStockScanner],
      "inventory.low_stock_detected"   => [Handlers::AlertCreator, Handlers::AgentTrigger],
      "alert.created"                  => [Handlers::NotificationDispatcher],
      "po.drafted"                     => [Handlers::SupplierNotifier],
      "agent.run_completed"            => [Handlers::BenchmarkRecorder],
    }.freeze

    def dispatch(event)
      handlers = HANDLERS[event[:event_type]] || []
      handlers.each { |h| h.new.call(event) }
    end
  end
end
```

### 4.4 Idempotency Guarantees

Every event handler MUST be idempotent. Implementation:

1. **Event ID deduplication** — `processed_events` Redis SET with 24h TTL. Check before processing.
2. **Database unique constraints** — e.g., one alert per variant per day (existing index `idx_alerts_variant_day`).
3. **Upsert patterns** — `INSERT ... ON CONFLICT DO UPDATE` for snapshot and product data.

---

## 5. Microservices Decomposition

We're not extracting to separate deployments yet. Instead, we enforce **service boundaries within the monolith** using Ruby modules with strict interfaces. Each "service" is a module under `app/services/` with a defined public API and event contract.

### 5.1 Service Map

| Service | Module | Responsibility | Public API |
|---|---|---|---|
| **Ingestion Gateway** | `Services::Ingestion` | HMAC verify, parse webhooks, publish events | `.receive_webhook(topic, headers, body)` |
| **Inventory Service** | `Services::Inventory` | Product/variant CRUD, snapshotting, low-stock detection | `.sync_shop(shop)`, `.snapshot(shop, data)`, `.detect_low_stock(shop)` |
| **Alerting Service** | `Services::Alerting` | Deduplicate, create alerts, manage alert lifecycle | `.process_low_stock(shop, variants)`, `.dismiss(alert_id)` |
| **AI Agent Service** | `Services::AIAgent` | Agentic inventory monitor, insights, PO drafting | `.run_monitor(shop)`, `.generate_insights(shop)`, `.draft_po(shop, supplier)` |
| **Notification Service** | `Services::Notifications` | Email, in-app, Slack dispatch | `.send_alert(alert)`, `.send_po(po)`, `.send_report(report)` |
| **Reporting Service** | `Services::Reports` | Weekly reports, trend analysis | `.generate_weekly(shop)`, `.get_trends(shop, period)` |
| **Benchmark Service** | `Services::Benchmark` | Timing, tracing, performance data | `.start_trace(name)`, `.end_trace(trace_id)`, `.report(period)` |
| **Cache Service** | `Services::Cache` | Read-through cache for dashboard data | `.dashboard_data(shop)`, `.invalidate(shop)` |

### 5.2 Service Boundary Rules

1. Services communicate ONLY via events or their public API methods.
2. No direct ActiveRecord queries across service boundaries — use the owning service's API.
3. Each service owns its database tables. Cross-service reads go through APIs.
4. Services are independently testable — mock the event bus and peer APIs.

### 5.3 Future Extraction Path

When scale demands it, each service module can become a standalone Rails engine or separate service:

```
Phase 1 (NOW):   Module boundaries within monolith
Phase 2 (1K shops): Rails engines with isolated routes
Phase 3 (10K shops): Separate deployments, Redis Streams → Kafka
```

---

## 6. API Documentation & Service Registry

### 6.1 Documentation Engine

**Library:** [Rswag](https://github.com/rswag/rswag) (OpenAPI/Swagger for Rails + RSpec)

Rswag generates OpenAPI 3.0 specs from RSpec request specs, giving us:
- Auto-generated, always-accurate API docs
- Swagger UI at `/api-docs`
- Machine-readable OpenAPI JSON for client generation
- Tests ARE the documentation — they can never drift

### 6.2 Endpoint Registry

#### Authentication Endpoints

| Method | Path | Auth | Description | Response |
|--------|------|------|-------------|----------|
| `GET` | `/auth/shopify/callback` | OAuth | Shopify OAuth callback — exchanges code for access token | Redirect to `/dashboard` |
| `GET` | `/auth/failure` | None | OAuth failure handler | Error page |
| `DELETE` | `/logout` | Session | Destroy current session | Redirect to `/` |
| `GET` | `/install` | None | Begin Shopify OAuth flow | Redirect to Shopify |

#### Health & Status

| Method | Path | Auth | Description | Response |
|--------|------|------|-------------|----------|
| `GET` | `/health` | None | Health check — DB, Redis, Sidekiq status | `{ status, db, redis, sidekiq, timestamp }` |
| `GET` | `/api/v1/benchmark/status` | Session | Current benchmark metrics summary | `{ pipeline_p50, pipeline_p99, agent_avg, uptime }` |

#### Inventory Endpoints

| Method | Path | Auth | Description | Response |
|--------|------|------|-------------|----------|
| `GET` | `/inventory` | Session | Paginated inventory list with stock levels | HTML (Polaris table) |
| `GET` | `/inventory/:id` | Session | Single variant detail with snapshot history | HTML (Polaris card) |
| `GET` | `/api/v1/inventory/summary` | Session | Inventory health summary (total, low, OOS) | `{ total_skus, healthy, low_stock, out_of_stock }` |
| `GET` | `/api/v1/inventory/snapshots` | Session | Time-series snapshot data for charting | `[{ variant_id, available, timestamp }]` |

#### Supplier Endpoints

| Method | Path | Auth | Description | Response |
|--------|------|------|-------------|----------|
| `GET` | `/suppliers` | Session | List all suppliers for current shop | HTML / JSON |
| `POST` | `/suppliers` | Session | Create a new supplier | `{ id, name, email, lead_time_days }` |
| `GET` | `/suppliers/:id` | Session | Supplier detail with associated variants | HTML / JSON |
| `PATCH` | `/suppliers/:id` | Session | Update supplier details | `{ id, name, email, lead_time_days }` |
| `DELETE` | `/suppliers/:id` | Session | Delete supplier (nullifies variant associations) | `204 No Content` |

#### Purchase Order Endpoints

| Method | Path | Auth | Description | Response |
|--------|------|------|-------------|----------|
| `GET` | `/purchase_orders` | Session | List all POs (filterable by status) | HTML / JSON |
| `POST` | `/purchase_orders` | Session | Create manual PO | `{ id, po_number, status, line_items }` |
| `GET` | `/purchase_orders/:id` | Session | PO detail with line items | HTML / JSON |
| `PATCH` | `/purchase_orders/:id/mark_sent` | Session | Mark PO as sent to supplier | `{ id, status: "sent", sent_at }` |
| `PATCH` | `/purchase_orders/:id/mark_received` | Session | Mark PO as received | `{ id, status: "received" }` |
| `POST` | `/purchase_orders/generate_draft` | Session | AI-generated PO draft for a supplier | `{ id, draft_body, line_items }` |

#### Alert Endpoints

| Method | Path | Auth | Description | Response |
|--------|------|------|-------------|----------|
| `GET` | `/alerts` | Session | List active alerts (paginated) | HTML / JSON |
| `PATCH` | `/alerts/:id/dismiss` | Session | Dismiss an alert | `{ id, status: "dismissed" }` |

#### AI Agent Endpoints

| Method | Path | Auth | Description | Response |
|--------|------|------|-------------|----------|
| `POST` | `/agents/run` | Session | Trigger agentic inventory monitor | `{ log, turns, actions_taken }` |
| `GET` | `/api/v1/agents/last_run` | Session | Results of most recent agent run | `{ log, turns, timestamp }` |
| `GET` | `/api/v1/insights` | Session | AI-generated inventory insights | `{ insights_text, generated_at }` |

#### Webhook Endpoints (Shopify → StockPilot)

| Method | Path | Auth | Description | Payload |
|--------|------|------|-------------|---------|
| `POST` | `/webhooks/app_uninstalled` | HMAC | App uninstalled — deactivate shop | Shopify shop object |
| `POST` | `/webhooks/products_update` | HMAC | Product created/updated | Shopify product object |
| `POST` | `/webhooks/products_delete` | HMAC | Product deleted | `{ id }` |

#### GDPR Endpoints (Mandatory)

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| `POST` | `/gdpr/customers_data_request` | HMAC | Export customer data |
| `POST` | `/gdpr/customers_redact` | HMAC | Delete customer data |
| `POST` | `/gdpr/shop_redact` | HMAC | Delete all shop data post-uninstall |

#### Benchmark Endpoints (New)

| Method | Path | Auth | Description | Response |
|--------|------|------|-------------|----------|
| `GET` | `/api/v1/benchmarks` | Session | Full benchmark dashboard data | `{ traces, percentiles, trends }` |
| `GET` | `/api/v1/benchmarks/pipeline` | Session | Pipeline timing breakdown | `{ stages: [{ name, p50, p95, p99 }] }` |
| `GET` | `/api/v1/benchmarks/agents` | Session | AI agent performance metrics | `{ avg_turns, avg_time, tool_call_times }` |
| `POST` | `/api/v1/benchmarks/run` | Session | Trigger a benchmark suite run | `{ trace_id, status: "started" }` |

### 6.3 Service Contracts (What We Provide)

| Service | Contract | SLA Target |
|---------|----------|------------|
| Webhook Ingestion | Accept, authenticate, and enqueue any Shopify webhook | < 50ms response, 99.9% uptime |
| Inventory Sync | Full shop inventory synced to local DB | < 30s for 1000 SKUs |
| Low-Stock Detection | Scan all variants against thresholds | < 500ms for 1000 SKUs |
| Alert Dispatch | Deduplicated alert creation + email send | < 2s end-to-end |
| AI Agent Analysis | Full agentic inventory review cycle | < 45s (depends on Claude API) |
| PO Draft Generation | AI-drafted purchase order for a supplier | < 15s per supplier |
| Weekly Report | Compiled trend analysis + email delivery | < 60s generation |
| Benchmark Trace | Full pipeline timing from webhook → action | Stored within 100ms of completion |

---

## 7. Performance Benchmarking System

### 7.1 Why Benchmarking

We need **proof, not promises**. Every claim about speed needs a number, a timestamp, and a trace ID. This system gives us:

1. **Pipeline timing** — How long from webhook receipt to supplier email?
2. **Stage-by-stage breakdown** — Where are the bottlenecks?
3. **AI agent profiling** — How long does each tool call take? How many turns on average?
4. **Trend analysis** — Are we getting faster or slower as data grows?
5. **Regression detection** — Did that deploy make things slower?

### 7.2 Benchmark Schema

```ruby
# db/migrate/XXXXXX_create_benchmark_traces.rb
create_table :benchmark_traces do |t|
  t.uuid     :trace_id,      null: false, index: { unique: true }
  t.bigint   :shop_id,       null: false, index: true
  t.string   :pipeline_name, null: false  # e.g., "webhook_to_alert", "full_agent_run"
  t.string   :status,        null: false, default: "in_progress"  # in_progress, completed, failed
  t.jsonb    :stages,        null: false, default: []
  # stages: [{ name: "ingestion", started_at: ..., ended_at: ..., duration_ms: ... }, ...]
  t.float    :total_duration_ms
  t.jsonb    :metadata,      default: {}
  t.datetime :started_at,    null: false
  t.datetime :completed_at
  t.timestamps
end

create_table :benchmark_stage_logs do |t|
  t.uuid     :trace_id,    null: false, index: true
  t.string   :stage_name,  null: false
  t.float    :duration_ms, null: false
  t.jsonb    :metadata,    default: {}
  t.datetime :recorded_at, null: false
  t.timestamps
end
```

### 7.3 Instrumentation Module

```ruby
# app/services/benchmark/tracer.rb
module Benchmark
  class Tracer
    def initialize(pipeline_name, shop_id:)
      @trace_id = SecureRandom.uuid
      @pipeline_name = pipeline_name
      @shop_id = shop_id
      @stages = []
      @started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC, :microsecond)
      @wall_started_at = Time.current
    end

    def stage(name)
      stage_start = Process.clock_gettime(Process::CLOCK_MONOTONIC, :microsecond)
      result = yield
      stage_end = Process.clock_gettime(Process::CLOCK_MONOTONIC, :microsecond)
      duration_ms = (stage_end - stage_start) / 1000.0

      @stages << {
        name: name,
        duration_ms: duration_ms.round(3),
        started_at: Time.current.iso8601(6),
        ended_at: Time.current.iso8601(6)
      }

      result
    end

    def complete!
      wall_end = Process.clock_gettime(Process::CLOCK_MONOTONIC, :microsecond)
      total_ms = (wall_end - @started_at) / 1000.0

      BenchmarkTrace.create!(
        trace_id: @trace_id,
        shop_id: @shop_id,
        pipeline_name: @pipeline_name,
        status: "completed",
        stages: @stages,
        total_duration_ms: total_ms.round(3),
        started_at: @wall_started_at,
        completed_at: Time.current
      )

      {
        trace_id: @trace_id,
        pipeline: @pipeline_name,
        total_ms: total_ms.round(3),
        stages: @stages
      }
    end

    attr_reader :trace_id
  end
end
```

### 7.4 What We Benchmark

#### Pipeline: Webhook → Alert (Target: < 2s)

| Stage | What | Target |
|-------|------|--------|
| `ingestion` | HMAC verify + parse + publish event | < 5ms |
| `persistence` | Upsert product/variant records | < 50ms |
| `snapshot` | Create inventory snapshot | < 30ms |
| `detection` | Low-stock threshold scan | < 100ms |
| `deduplication` | Check for existing alerts today | < 20ms |
| `alert_creation` | Insert alert record | < 10ms |
| `email_dispatch` | Queue alert email via ActionMailer | < 50ms |
| **Total** | | **< 265ms** (excluding email delivery) |

#### Pipeline: Webhook → Supplier PO Email (Target: < 30s)

| Stage | What | Target |
|-------|------|--------|
| `ingestion` → `detection` | Same as above | < 265ms |
| `agent_init` | Initialize Anthropic client + context | < 100ms |
| `agent_tool_check_inventory` | Tool: scan all SKUs | < 200ms |
| `agent_tool_get_recent_alerts` | Tool: check today's alerts | < 50ms |
| `agent_tool_send_alerts` | Tool: create deduplicated alerts | < 100ms |
| `agent_tool_draft_po` | Tool: create PO + line items | < 200ms |
| `claude_api_calls` | Anthropic API round-trips (3-5 turns) | < 15s |
| `po_email_dispatch` | Queue supplier PO email | < 50ms |
| **Total** | | **< 16s** (dominated by Claude API latency) |

#### Pipeline: Full Agent Run (Target: < 45s)

| Stage | What | Target |
|-------|------|--------|
| `agent_init` | Setup + system prompt | < 100ms |
| `turn_N` | Each agentic turn (Claude API call + tool execution) | < 5s avg |
| `total_turns` | Expected 3-7 turns | < 35s |
| `result_persistence` | Store agent results on shop | < 50ms |
| **Total** | | **< 35s average** |

### 7.5 Benchmark Dashboard

A dedicated `/benchmarks` page showing:

1. **Pipeline P50/P95/P99** — Real-time percentile charts for each pipeline.
2. **Stage Waterfall** — Click any trace to see a waterfall diagram of stage timings.
3. **Agent Profiling** — Average turns, tool call distribution, Claude API latency.
4. **Trend Lines** — Rolling 7-day performance trends. Detect regressions.
5. **Leaderboard** — Fastest trace, slowest trace, most agent turns.

### 7.6 Benchmark CLI

```bash
# Run a benchmark suite against the local instance
bundle exec rake benchmark:webhook_pipeline    # Simulates webhook → alert
bundle exec rake benchmark:agent_run           # Runs full agent loop
bundle exec rake benchmark:full_pipeline       # Webhook → PO email
bundle exec rake benchmark:report              # Generate timing report
```

---

## 8. Agentic Testing Infrastructure

### 8.1 Philosophy

In an agentic-first world, traditional unit tests are necessary but insufficient. We need tests that validate **autonomous decision-making pipelines** end-to-end. The AI agent should be tested the same way we'd evaluate a human employee: give it a scenario, let it run, verify it made the right calls.

### 8.2 Test Levels

#### Level 1: Unit Tests (Existing — Enhance)

Test individual service methods in isolation. Mock external APIs.

| Area | Files | What to Test |
|------|-------|-------------|
| Event Publisher | `spec/services/events/publisher_spec.rb` | Correct envelope format, Redis stream append, trace ID propagation |
| Event Router | `spec/services/events/router_spec.rb` | Correct handler dispatch, unknown event handling, multi-handler fanout |
| Benchmark Tracer | `spec/services/benchmark/tracer_spec.rb` | Stage timing accuracy (within 1ms), trace persistence, completion status |
| Each Event Handler | `spec/services/events/handlers/*_spec.rb` | Idempotency, correct event emission, error handling |

#### Level 2: Integration Tests (New)

Test service-to-service communication via events.

| Scenario | What Happens | Verification |
|----------|-------------|--------------|
| Webhook ingestion → inventory persistence | Publish `webhook.received`, verify product/variant upserted | DB state matches webhook payload |
| Low-stock detection → alert creation | Publish `inventory.snapshot_created`, verify alert record exists | Alert created, no duplicates |
| Alert creation → email dispatch | Publish `alert.created`, verify mailer queued | ActionMailer job in Sidekiq queue |
| Agent trigger → PO creation | Publish `inventory.low_stock_detected`, verify PO exists | PO with correct line items |

#### Level 3: Agentic Pipeline Tests (New — Critical)

Full end-to-end tests that simulate the AI agent receiving a realistic scenario and validate its autonomous decisions.

```ruby
# spec/agentic/inventory_monitor_pipeline_spec.rb
RSpec.describe "Agentic Inventory Monitor Pipeline", :agentic do
  let(:shop) { create(:shop, :with_products) }

  before do
    # Seed: 50 variants, 5 suppliers, 10 below threshold, 3 at zero
    create_list(:variant, 40, :healthy, shop: shop)
    create_list(:variant, 7, :low_stock, shop: shop)
    create_list(:variant, 3, :out_of_stock, shop: shop)
  end

  it "detects all low-stock items, sends deduplicated alerts, and drafts POs" do
    tracer = Benchmark::Tracer.new("agentic_pipeline_test", shop_id: shop.id)

    result = tracer.stage("agent_run") do
      Agents::InventoryMonitor.new(shop).run
    end

    trace = tracer.complete!

    # Agent completed successfully
    expect(result[:error]).to be_nil
    expect(result[:turns]).to be_between(2, 10)

    # All low-stock variants have alerts
    expect(Alert.where(shop: shop).count).to eq(10)

    # No duplicate alerts
    expect(Alert.where(shop: shop).group(:variant_id).having("count(*) > 1").count).to be_empty

    # POs drafted for suppliers with multiple low-stock items
    expect(PurchaseOrder.where(shop: shop, status: "draft").count).to be >= 1

    # Performance: agent completed within SLA
    expect(trace[:total_ms]).to be < 45_000  # 45 seconds

    # Log the benchmark for the report
    puts "Agent pipeline: #{trace[:total_ms].round(0)}ms, #{result[:turns]} turns"
  end
end
```

#### Level 4: Chaos/Resilience Tests (New)

Validate the system handles failures gracefully.

| Scenario | Simulation | Expected Behavior |
|----------|-----------|-------------------|
| Claude API timeout | Stub Anthropic client to timeout after 10s | Agent falls back to direct check, alerts still sent |
| Claude API 500 | Stub Anthropic client to return 500 | Agent falls back, error logged to Sentry |
| Redis down | Stop Redis before event publish | Graceful degradation — inline processing, logged warning |
| Duplicate webhook | Send same webhook payload twice (same event ID) | Second delivery is a no-op |
| Slow database | Add 500ms latency to DB queries | Pipeline still completes, benchmark trace shows degradation |
| Concurrent agent runs | Trigger 3 agent runs for same shop simultaneously | Only 1 executes, others skip (advisory lock) |

#### Level 5: Load & Performance Tests (New)

Measure system behavior under realistic load.

```ruby
# spec/performance/pipeline_load_spec.rb
RSpec.describe "Pipeline Load Test", :performance do
  it "handles 100 concurrent webhook deliveries within SLA" do
    shops = create_list(:shop, 10, :with_products)
    traces = Concurrent::Array.new

    # Simulate 100 webhooks across 10 shops
    threads = 100.times.map do |i|
      Thread.new do
        shop = shops[i % 10]
        tracer = Benchmark::Tracer.new("load_test_webhook", shop_id: shop.id)
        tracer.stage("process") do
          Events::Publisher.publish("webhook.received",
            shop_id: shop.id,
            payload: build(:webhook_payload, :products_update))
        end
        traces << tracer.complete!
      end
    end

    threads.each(&:join)

    durations = traces.map { |t| t[:total_ms] }
    p50 = percentile(durations, 50)
    p99 = percentile(durations, 99)

    expect(p50).to be < 100   # 100ms p50
    expect(p99).to be < 500   # 500ms p99

    puts "Load test: p50=#{p50.round(1)}ms, p99=#{p99.round(1)}ms"
  end
end
```

### 8.3 Agentic Test Harness

A custom test runner that provides **autonomous execution** — it runs every test category, collects results, and produces a verification report.

```bash
# Run the full agentic test suite
bundle exec rake test:agentic

# This runs, in order:
# 1. Unit tests (rspec spec/services/events/ spec/services/benchmark/)
# 2. Integration tests (rspec spec/integration/)
# 3. Agentic pipeline tests (rspec spec/agentic/)
# 4. Resilience tests (rspec spec/resilience/)
# 5. Performance benchmarks (rspec spec/performance/)
# 6. Generates timing report to tmp/benchmark_report.json
```

---

## 9. Developer Blog

### 9.1 Library

**[Bridgetown](https://www.bridgetownrb.com/)** — A Ruby-powered static site generator. Chosen because:
- Same language as our backend (Ruby) — no context switching
- Supports ERB templates (consistent with our Rails views)
- Built-in Markdown + code syntax highlighting
- Static output — deploy to GitHub Pages or Netlify for free
- Active community, Shopify developers will recognize it

### 9.2 Blog Structure

```
blog/
├── bridgetown.config.yml
├── src/
│   ├── _posts/
│   │   ├── 2026-03-17-why-event-driven-architecture.md
│   │   ├── 2026-03-17-benchmarking-our-inventory-pipeline.md
│   │   ├── 2026-03-17-building-ai-agents-for-inventory.md
│   │   ├── 2026-03-17-multi-tenancy-lessons.md
│   │   └── 2026-03-17-agentic-testing-patterns.md
│   ├── _layouts/
│   │   └── post.erb
│   └── index.md
└── Gemfile  # Separate from main app
```

### 9.3 Initial Blog Posts (Engineering Decisions)

| # | Title | Topic | Source |
|---|-------|-------|--------|
| 1 | "Why We Chose Event-Driven Architecture for a Shopify App" | Event bus design, Redis Streams, service boundaries | TD-008 |
| 2 | "Benchmarking Our Inventory Pipeline: Proving Speed with Data" | Tracing system, stage timing, microsecond precision | TD-009 |
| 3 | "Building AI Agents That Monitor Inventory Autonomously" | Agentic loop design, tool calling, fallback patterns | TD-001, TD-006 |
| 4 | "Multi-Tenancy in Rails: What `acts_as_tenant` Gets Right (and Wrong)" | Tenant isolation, security implications, testing challenges | TD-001 |
| 5 | "Agentic Testing: How We Validate Autonomous AI Pipelines" | Test levels, chaos testing, performance validation | New |

### 9.4 Blog Build & Deploy

```bash
cd blog && bundle exec bridgetown build    # Build static site
cd blog && bundle exec bridgetown serve    # Local preview
# Deploy: GitHub Actions → GitHub Pages on push to main
```

---

## 10. Testing Plan

### 10.1 Morning Verification Checklist

This is designed so you can walk through it sequentially and verify everything works.

#### Phase 1: Infrastructure (5 min)

```bash
# 1. Verify database migrations ran
bundle exec rails db:migrate:status

# 2. Verify Redis connection
bundle exec rails runner "puts Redis.new.ping"

# 3. Verify Sidekiq processes events
bundle exec sidekiq -C config/sidekiq.yml &
```

#### Phase 2: Event System (10 min)

```bash
# 4. Run event system unit tests
bundle exec rspec spec/services/events/ --format documentation

# 5. Verify event publisher writes to Redis Stream
bundle exec rails runner "
  event = Events::Publisher.publish('test.ping', shop_id: 1, payload: { test: true })
  puts event[:event_id] ? 'PASS: Event published' : 'FAIL'
"

# 6. Verify event router dispatches correctly
bundle exec rspec spec/services/events/router_spec.rb --format documentation
```

#### Phase 3: Benchmarking (10 min)

```bash
# 7. Run benchmark tracer unit tests
bundle exec rspec spec/services/benchmark/ --format documentation

# 8. Run a pipeline benchmark
bundle exec rake benchmark:webhook_pipeline

# 9. Verify benchmark trace was recorded
bundle exec rails runner "
  trace = BenchmarkTrace.last
  puts trace ? \"PASS: #{trace.pipeline_name} - #{trace.total_duration_ms}ms\" : 'FAIL: No trace'
"
```

#### Phase 4: Agentic Pipeline (15 min)

```bash
# 10. Run agentic pipeline tests (mocked Claude API)
bundle exec rspec spec/agentic/ --format documentation

# 11. Run resilience tests
bundle exec rspec spec/resilience/ --format documentation

# 12. Verify agent fallback works when API is down
bundle exec rspec spec/services/agents/ --format documentation
```

#### Phase 5: Full Suite (10 min)

```bash
# 13. Run the entire test suite
bundle exec rspec --format documentation

# 14. Run RuboCop
bundle exec rubocop

# 15. Run Brakeman security scan
bundle exec brakeman -q

# 16. Generate benchmark report
bundle exec rake benchmark:report
```

#### Phase 6: Blog (5 min)

```bash
# 17. Verify blog builds
cd blog && bundle install && bundle exec bridgetown build

# 18. Preview blog locally
bundle exec bridgetown serve  # Visit http://localhost:4002
```

### 10.2 Acceptance Criteria

| # | Criterion | How to Verify | Pass/Fail |
|---|-----------|---------------|-----------|
| AC-1 | Events publish to Redis Streams with correct envelope schema | Unit test + manual runner command | |
| AC-2 | Event router dispatches to correct handlers | Unit test | |
| AC-3 | Handlers are idempotent (duplicate events are no-ops) | Integration test | |
| AC-4 | Benchmark tracer records stage-level timing with < 1ms accuracy | Unit test | |
| AC-5 | Full webhook → alert pipeline benchmarked end-to-end | `rake benchmark:webhook_pipeline` produces trace | |
| AC-6 | Agent pipeline benchmarked with per-tool-call timing | `rake benchmark:agent_run` produces trace | |
| AC-7 | Benchmark dashboard endpoint returns percentile data | Request spec | |
| AC-8 | Agent falls back correctly when Claude API fails | Resilience spec with stubbed timeout | |
| AC-9 | Duplicate webhooks are rejected (idempotency) | Integration spec | |
| AC-10 | Concurrent agent runs for same shop are serialized | Concurrency spec with advisory lock | |
| AC-11 | API documentation available at `/api-docs` | Visit URL, verify Swagger UI loads | |
| AC-12 | All endpoints documented with request/response examples | Rswag specs generate valid OpenAPI | |
| AC-13 | Blog builds and serves locally | `bridgetown build` exits 0, `serve` renders | |
| AC-14 | At least 5 engineering blog posts with code examples | File count in `blog/src/_posts/` | |
| AC-15 | `rake test:agentic` runs all 5 test levels sequentially | Exit code 0, report generated | |
| AC-16 | Performance: webhook → alert pipeline < 500ms p99 | Benchmark trace data | |
| AC-17 | Performance: full agent run < 45s average (mocked API: < 5s) | Benchmark trace data | |
| AC-18 | Service boundaries enforced — no cross-module AR queries | Code review + grep for violations | |

### 10.3 Test Coverage Targets

| Area | Current | Target | Notes |
|------|---------|--------|-------|
| Models | ~90% | 95% | Add edge cases for validations |
| Services | ~80% | 95% | Add event publisher/consumer/handler tests |
| Jobs | ~85% | 95% | Add idempotency tests |
| Controllers | ~70% | 90% | Add Rswag request specs |
| Event System | 0% | 95% | New — full coverage from day 1 |
| Benchmark System | 0% | 95% | New — full coverage from day 1 |
| Agentic Pipeline | 0% | 80% | Hard to get 100% with AI — focus on behavior verification |
| Resilience | ~30% | 80% | Expand chaos scenarios |

---

## 11. Autonomous Execution Contract

### 11.1 Definition of Done (Per Item)

Each item in this PRD is considered **complete** when:

1. **Code exists** — Implementation committed to the feature branch
2. **Tests pass** — All relevant specs green (`bundle exec rspec` exit 0)
3. **Lint passes** — `bundle exec rubocop` exit 0
4. **No regressions** — Full test suite still passes
5. **Benchmarked** — If the item involves a pipeline, a benchmark trace exists proving timing
6. **Documented** — Endpoint added to API docs, service added to registry, decision logged in `TECHNICAL_DECISIONS.md`

### 11.2 Execution Order

The implementation MUST follow this order (each step blocks on the previous):

```
Step 1:  Event schema + publisher + consumer + router (foundation)
Step 2:  Event handlers for existing flows (wire in events)
Step 3:  Benchmark tracer + benchmark_traces table (measurement)
Step 4:  Instrument existing pipelines with tracer (data collection)
Step 5:  Benchmark rake tasks (CLI tooling)
Step 6:  Rswag setup + API documentation specs (docs)
Step 7:  Agentic pipeline test harness (testing)
Step 8:  Resilience tests (chaos)
Step 9:  Performance/load tests (proof)
Step 10: Blog setup + initial posts (communication)
Step 11: Benchmark dashboard endpoint (visualization)
Step 12: Full test:agentic rake task (orchestration)
```

### 11.3 Autonomous Verification Loop

After each step, the implementing agent MUST:

```
1. Run: bundle exec rspec [relevant specs]
2. Run: bundle exec rubocop [changed files]
3. Verify: no test regressions (full suite)
4. Log: timing data for any benchmarked pipeline
5. Commit: with descriptive message referencing this PRD
6. Only then: proceed to next step
```

If any step fails, the agent MUST fix the issue before proceeding. No skipping. No "TODO later". Each step is complete or it blocks everything downstream.

---

## Appendix A: User Stories

| ID | Story | Priority | PRD Section |
|----|-------|----------|-------------|
| US-050 | As a developer, I want all service communication via events so I can independently scale and test each service | P0 | §4 |
| US-051 | As a developer, I want every pipeline stage timed with microsecond precision so I can identify bottlenecks | P0 | §7 |
| US-052 | As a merchant, I want to see how fast my inventory updates are processed so I trust the system | P1 | §7.5 |
| US-053 | As a developer, I want API docs auto-generated from tests so they never drift from reality | P1 | §6 |
| US-054 | As a developer, I want agentic pipeline tests that validate the AI makes correct autonomous decisions | P0 | §8.3 |
| US-055 | As a developer, I want chaos tests that prove the system degrades gracefully | P1 | §8.2 Level 4 |
| US-056 | As a developer, I want performance tests proving our SLA targets under load | P1 | §8.2 Level 5 |
| US-057 | As a company, I want a public engineering blog to share our technical decisions | P2 | §9 |
| US-058 | As a developer, I want a single `rake test:agentic` command that runs all test levels and produces a report | P1 | §8.3 |
| US-059 | As a developer, I want benchmark trend analysis to detect performance regressions across deploys | P2 | §7.5 |

---

## Appendix B: Technical Decisions to Log

| TD # | Decision | Section |
|------|----------|---------|
| TD-008 | Event-driven architecture via Redis Streams + Sidekiq (not Kafka) | §4.1 |
| TD-009 | Monotonic clock + microsecond precision for benchmark timing | §7.3 |
| TD-010 | Service boundaries within monolith (modular monolith, not microservices) | §5.1 |
| TD-011 | Rswag for API documentation (tests = docs) | §6.1 |
| TD-012 | Bridgetown for engineering blog (Ruby ecosystem consistency) | §9.1 |
| TD-013 | 5-level test pyramid for agentic systems | §8.2 |
| TD-014 | Idempotency via Redis SET + DB unique constraints | §4.4 |

---

*This PRD is a living document. Update it as implementation reveals new requirements or changes priorities.*
