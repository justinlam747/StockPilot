# PRD: StockPilot AI Inventory Copilot

## 1. Overview

StockPilot currently gives Shopify merchants inventory visibility, low-stock alerts, supplier management, purchase order workflows, audit logging, and a persisted agent-run surface. The AI Inventory Copilot extends that foundation into a human-in-the-loop recommendation system.

The v1 implementation should stay inside the existing Rails app. It should use deterministic, inspectable business rules first, store recommendations as `agent_actions`, let merchants approve/reject/edit those recommendations, and convert accepted actions into real workflows such as purchase orders or threshold updates.

This feature must not depend on a new Python service, LangGraph, or complex forecasting for v1. The first version should be truthful, useful, testable, and aligned with the code already present in `Agents::InventoryMonitor`, `AgentRunJob`, `AgentRun`, `AgentAction`, `PurchaseOrder`, `PurchaseOrderLineItem`, `Supplier`, `Variant`, and `InventorySnapshot`.

## 2. Goals

- Turn passive inventory alerts into concrete recommendations.
- Reduce stockouts by recommending reorder quantities and supplier actions.
- Preserve merchant control through approval, rejection, and editing.
- Store recommendation reasoning and feedback for auditability.
- Convert accepted recommendations into purchase orders or configuration changes.
- Capture lightweight merchant preferences for future recommendations.

## 3. Non-Goals

- No Python service in v1.
- No real-time demand forecasting in v1.
- No multi-location warehouse transfer optimization in v1.
- No autonomous purchase order sending without merchant approval.
- No replacement of existing Rails background job architecture.
- No broad redesign of the app shell or dashboard.

## 4. Success Metrics

- Percentage of low-stock/out-of-stock variants that receive recommendations.
- Percentage of recommendations accepted by merchants.
- Percentage of accepted reorder recommendations converted into purchase orders.
- Median time from alert creation to purchase order creation.
- Reduction in repeated stockouts for the same SKU over time.
- Number of recommendations edited before acceptance, grouped by edit type.

## 5. Existing System Context

Relevant current code:

- `app/services/agents/runner.rb`
- `app/services/agents/inventory_monitor.rb`
- `app/services/agents/run_logger.rb`
- `app/services/agents/summary_client.rb`
- `app/jobs/agent_run_job.rb`
- `app/controllers/agents_controller.rb`
- `app/models/agent_run.rb`
- `app/models/agent_action.rb`
- `app/models/variant.rb`
- `app/models/supplier.rb`
- `app/models/purchase_order.rb`
- `app/models/purchase_order_line_item.rb`
- `app/models/inventory_snapshot.rb`
- `app/services/inventory/low_stock_detector.rb`

Current agent flow:

1. Merchant clicks run agent.
2. `Agents::Runner.run_for_shop` creates or reuses an active `AgentRun`.
3. `AgentRunJob` claims the run and executes `Agents::InventoryMonitor`.
4. `InventoryMonitor` detects flagged variants and creates proposed `AgentAction` records.
5. Agent run page shows events and actions.

This PRD evolves that flow rather than replacing it.

## 6. Users

Primary user:

- Shopify merchant, operator, or inventory manager.

Core user needs:

- Know which SKUs need action.
- Understand why action is recommended.
- Know how much to reorder.
- Know which supplier should fulfill the reorder.
- Approve or modify recommendations quickly.
- Trust that the system will not take irreversible action without approval.

## 7. Product Requirements

### 7.1 Recommendation Engine

Create a Rails service:

```text
app/services/agents/recommendation_engine.rb
```

Public API:

```ruby
Agents::RecommendationEngine.call(shop:, goal: nil, correction: nil)
```

The engine should return structured recommendation hashes, not ActiveRecord objects.

Recommended output shape:

```ruby
{
  action_type: "reorder_recommendation",
  title: "Reorder SKU-123 from TextileCo",
  details: "SKU-123 is below threshold with 4 available and a 14 day supplier lead time.",
  payload: {
    variant_id: 123,
    product_id: 456,
    supplier_id: 45,
    sku: "SKU-123",
    product_title: "Cotton Tee",
    variant_title: "Medium / Black",
    current_quantity: 4,
    threshold: 10,
    recommended_quantity: 30,
    recommendation_basis: {
      available: 4,
      threshold: 10,
      lead_time_days: 14,
      target_days: 30,
      min_order_qty: 0
    }
  }
}
```

Minimum recommendation types:

- `reorder_recommendation`
- `supplier_grouping`
- `purchase_order_draft`
- `threshold_adjustment`

Future recommendation type:

- `stock_transfer_recommendation`

### 7.2 Reorder Recommendation Logic

For each low-stock or out-of-stock variant:

1. Use `Inventory::LowStockDetector` to identify flagged variants.
2. Determine the applicable threshold:
   - `variant.low_stock_threshold`, if present;
   - otherwise `shop.low_stock_threshold`.
3. Determine supplier:
   - `variant.supplier`, if assigned;
   - otherwise create a supplier-assignment recommendation instead of a reorder.
4. Determine target coverage window:
   - `shop.settings["agent_preferences"]["default_reorder_days"]`;
   - default to 30 days.
5. Calculate recommended quantity with a conservative rule:

```text
recommended_quantity = max(threshold, (threshold * 2) - current_quantity)
```

6. Apply preference constraints:
   - respect `min_order_qty`, if configured;
   - skip SKUs listed in `ignored_skus`;
   - prefer explicitly configured suppliers when available.

For v1, do not claim the recommendation is demand-forecasted. The reasoning should clearly say it is threshold and lead-time based.

### 7.3 Supplier Grouping

When multiple reorder recommendations share a supplier, generate a grouping action.

The grouping action should:

- list all recommended variants for that supplier;
- include supplier email and lead time;
- calculate a total line count;
- be convertible into one purchase order.

The engine may create both individual reorder actions and supplier grouping actions, but the UI should make it clear which action will create a purchase order.

### 7.4 Purchase Order Draft Recommendation

For recommendations with suppliers, create an action that can become a draft `PurchaseOrder`.

Payload should include:

- `supplier_id`;
- `source_agent_run_id`;
- line items with `variant_id`, `sku`, `title`, `qty_ordered`, and optional `unit_price`;
- reasoning per line item.

### 7.5 Threshold Adjustment Recommendation

If the same SKU repeatedly triggers low-stock alerts, recommend a threshold adjustment.

v1 rule:

- If a variant has 3 or more active or historical alerts in the last 30 days, recommend increasing its threshold.

Payload should include:

- `variant_id`;
- `current_threshold`;
- `recommended_threshold`;
- `alert_count_30d`;
- `reason`.

The action should only update `variant.low_stock_threshold` after merchant approval.

## 8. Agent Integration

Update:

```text
app/services/agents/inventory_monitor.rb
```

Expected flow:

1. Log start event.
2. Run `Agents::RecommendationEngine`.
3. Persist recommendations as `AgentAction` records.
4. Log count by recommendation type.
5. Generate summary using existing `Agents::SummaryClient`.
6. Store structured result payload on `AgentRun`.

`AgentAction` creation should remain centralized through `Agents::RunLogger#propose_action!` or a small new helper method, so event/action persistence stays consistent.

## 9. Data Model Requirements

### 9.1 Extend `agent_actions`

Current fields include:

- `agent_run_id`;
- `action_type`;
- `status`;
- `title`;
- `details`;
- `payload`;
- `resolution_note`;
- timestamps.

Add:

```ruby
feedback_note :text
resolved_at :datetime
resolved_by :string
```

Update allowed statuses in `AgentAction::STATUSES`:

```ruby
%w[proposed accepted rejected edited applied failed]
```

Notes:

- Keep `payload` as the structured JSONB store.
- Do not add a separate `metadata` column unless there is a specific need; current schema already uses `payload` for action data.
- Preserve `resolution_note` for system-generated outcome notes.
- Use `feedback_note` for merchant-entered feedback.

### 9.2 Optional Purchase Order Source Fields

For traceability, add source metadata to purchase orders:

```ruby
source :string
source_agent_run_id :bigint
source_agent_action_id :bigint
```

Alternative v1 option:

- Store this in `purchase_orders.po_notes` to avoid a migration.

Recommended implementation:

- Add explicit columns if the feature is being built for portfolio/resume quality.

### 9.3 Shop Preference Memory

Use existing `shops.settings` JSONB.

Suggested structure:

```json
{
  "agent_preferences": {
    "default_reorder_days": 30,
    "min_order_qty": 50,
    "preferred_suppliers": {},
    "ignored_skus": []
  }
}
```

Add helper methods on `Shop`:

```ruby
def agent_preferences
  settings["agent_preferences"] || {}
end

def update_agent_preferences!(updates)
  update!(settings: settings.merge("agent_preferences" => agent_preferences.merge(updates)))
end
```

## 10. Human-in-the-Loop Controls

Merchants must be able to:

- accept a recommendation;
- reject a recommendation;
- edit recommended quantity;
- edit supplier for reorder/purchase-order actions;
- add feedback notes;
- see when an action was resolved;
- see whether accepting the action created or updated another record.

Statuses:

- `proposed`: initial state.
- `accepted`: merchant accepted but workflow has not necessarily been applied.
- `edited`: merchant changed recommendation data.
- `rejected`: merchant rejected.
- `applied`: workflow was successfully executed.
- `failed`: workflow attempted but failed.

Rules:

- Only `proposed` and `edited` actions can be accepted or rejected.
- Applied actions cannot be edited.
- Rejecting requires no workflow side effects.
- Editing updates `payload`, sets status to `edited`, and records feedback if provided.

## 11. Workflow Automation

Create a service:

```text
app/services/agents/action_applier.rb
```

Public API:

```ruby
Agents::ActionApplier.call(action:, actor: nil, params: {})
```

Responsibilities:

- Validate that action belongs to current shop through `action.agent_run.shop`.
- Apply side effects based on `action_type`.
- Update action status, resolution fields, and notes.
- Record `AuditLog` entries.

Action behavior:

| Action type | Accepted behavior |
| --- | --- |
| `reorder_recommendation` | Create or append to draft purchase order for the supplier. |
| `supplier_grouping` | Create one draft purchase order with grouped line items. |
| `purchase_order_draft` | Create one draft purchase order from payload line items. |
| `threshold_adjustment` | Update `variant.low_stock_threshold`. |

Purchase order creation rules:

- Create `PurchaseOrder` with `status: "draft"`.
- Set `supplier_id` from payload.
- Create `PurchaseOrderLineItem` rows from payload.
- Use current date as `order_date`.
- Set `expected_delivery` from supplier lead time when present.
- Store source agent context.
- Do not mark the PO sent.
- Do not email supplier automatically in v1.

## 12. Controller and Route Requirements

Extend `AgentsController` or create a dedicated controller.

Recommended dedicated controller:

```text
app/controllers/agent_actions_controller.rb
```

Routes:

```ruby
resources :agent_actions, only: [] do
  member do
    patch :accept
    patch :reject
    patch :edit_recommendation
  end
end
```

Controller actions:

- `accept`: applies the action through `Agents::ActionApplier`.
- `reject`: marks action rejected with optional feedback.
- `edit_recommendation`: updates editable payload fields and marks action edited.

Security:

- Require connected shop.
- Load action through `current_shop.agent_runs.joins(:actions)` or equivalent shop-scoped lookup.
- Never find `AgentAction` globally without checking shop ownership.

## 13. UI Requirements

Update:

```text
app/views/agents/show.html.erb
```

Add a recommendations section that displays:

- action type;
- title;
- details/reasoning;
- status badge;
- supplier;
- SKU/product details;
- recommended quantity;
- expected workflow result;
- accept/reject/edit controls.

Edit UI:

- quantity input for reorder actions;
- supplier select for reorder actions;
- threshold input for threshold recommendations;
- feedback note textarea.

Accepted/applied UI:

- show linked purchase order when created;
- show updated threshold when applied;
- show resolved timestamp.

Rejected UI:

- show feedback note, if provided.

Use existing app styling and partial patterns. Keep the first version server-rendered. HTMX can be used for row-level updates, but it is not required.

## 14. Summary Layer

Update:

```text
app/services/agents/summary_client.rb
```

The summary context should include:

- count of low-stock SKUs;
- count of out-of-stock SKUs;
- count of reorder recommendations;
- count of supplierless SKUs;
- number of purchase order draft recommendations;
- top urgent SKUs;
- supplier grouping count.

Example fallback summary:

```text
You have 12 flagged SKUs: 7 low stock and 5 out of stock. StockPilot recommends 8 reorder actions across 3 suppliers, with 2 urgent out-of-stock items requiring immediate review. Three flagged SKUs are missing supplier assignments.
```

The AI provider path should stay optional. The feature must work when `AI_PROVIDER=disabled`.

## 15. Preference Learning

Create a small service:

```text
app/services/agents/preference_learner.rb
```

Public API:

```ruby
Agents::PreferenceLearner.call(action:, outcome:)
```

v1 learning rules:

- If merchant repeatedly edits quantities upward, increase `default_reorder_days` modestly.
- If merchant repeatedly edits quantities downward, lower `default_reorder_days` modestly.
- If merchant rejects recommendations for the same SKU more than twice, add SKU to `ignored_skus` only after explicit confirmation in a later phase.
- If merchant changes supplier for a SKU, store preferred supplier mapping.

For v1, keep learning conservative and transparent. Do not silently ignore SKUs without making that visible to the merchant.

## 16. Audit Logging

Record audit events for:

- recommendation accepted;
- recommendation rejected;
- recommendation edited;
- recommendation applied;
- recommendation application failed;
- purchase order generated from recommendation;
- threshold updated from recommendation.

Metadata should include:

- `agent_run_id`;
- `agent_action_id`;
- `action_type`;
- target record IDs;
- before/after values for threshold changes;
- purchase order ID when created.

## 17. Testing Requirements

### Model Specs

Update:

- `spec/models/agent_action_spec.rb`
- `spec/models/shop_spec.rb`
- optionally `spec/models/purchase_order_spec.rb`

Coverage:

- new statuses are valid;
- feedback fields persist;
- resolved timestamps are optional until resolved;
- shop agent preference helpers return defaults and merge updates.

### Service Specs

Add:

```text
spec/services/agents/recommendation_engine_spec.rb
spec/services/agents/action_applier_spec.rb
spec/services/agents/preference_learner_spec.rb
```

Coverage:

- recommendations generated for low-stock variants;
- recommendations generated for out-of-stock variants;
- supplierless variants create supplier assignment/grouping guidance instead of invalid PO payloads;
- ignored SKUs are skipped;
- min order quantity is respected;
- supplier grouping combines variants correctly;
- threshold adjustment recommendation appears after repeated alerts;
- accepted reorder creates draft purchase order and line items;
- accepted threshold action updates variant threshold;
- rejected action has no workflow side effects;
- failed apply marks action failed and records reason.

### Job Specs

Update:

- `spec/jobs/agent_run_job_spec.rb`

Coverage:

- agent run creates recommendation actions;
- failures are persisted on the run;
- existing active-run behavior remains unchanged.

### Request Specs

Add:

```text
spec/requests/agent_actions_html_spec.rb
```

Coverage:

- accept action;
- reject action;
- edit recommendation;
- tenant isolation prevents cross-shop action access;
- invalid payload returns validation error.

### UI/HTML Specs

Update:

- `spec/requests/agents_html_spec.rb`

Coverage:

- agent show page displays recommendation list;
- proposed actions show accept/reject/edit controls;
- applied actions show linked purchase order.

## 18. Acceptance Criteria

Phase 1 is complete when:

- `Agents::RecommendationEngine` exists and is covered by specs.
- `Agents::InventoryMonitor` stores recommendation actions from the engine.
- Agent run page displays structured recommendations.
- Recommendations include clear reasoning and quantities.
- Summary mentions recommendation counts.
- Feature works without external AI provider.

Phase 2 is complete when:

- Agent actions can be accepted, rejected, and edited.
- Accepted reorder/grouping/draft actions create draft purchase orders.
- Accepted threshold recommendations update variant thresholds.
- Rejected actions have no side effects.
- Audit logs are recorded.
- Request specs cover tenant isolation.

Phase 3 is complete when:

- `shop.settings["agent_preferences"]` affects recommendations.
- Basic preference learning updates settings from merchant behavior.
- Preferences are visible or at least inspectable in settings/admin context.

Phase 4 is only eligible when:

- Rails v1 recommendation flow is stable.
- Acceptance/rejection metrics are available.
- There is a clear optimization problem that deterministic Rails rules cannot solve.

## 19. Implementation Milestones

### Milestone 1: Recommendation Engine

- Add `Agents::RecommendationEngine`.
- Add recommendation output structs/hashes.
- Add specs for reorder, supplierless, grouping, and threshold recommendations.
- Integrate engine into `Agents::InventoryMonitor`.
- Update summary context.

### Milestone 2: Data Model and UI

- Add migration for `agent_actions.feedback_note`, `resolved_at`, and `resolved_by`.
- Update `AgentAction::STATUSES`.
- Add recommendations partial to agent run page.
- Add status badges and payload rendering.

### Milestone 3: Human Approval

- Add `AgentActionsController`.
- Add accept/reject/edit routes.
- Add `Agents::ActionApplier`.
- Add purchase order creation from accepted actions.
- Add audit logs.
- Add request specs.

### Milestone 4: Preference Memory

- Add shop preference helpers.
- Add `Agents::PreferenceLearner`.
- Apply preferences in recommendation engine.
- Add tests for preference effects.

### Milestone 5: Polish and Metrics

- Add dashboard or agent page counts for accepted/rejected/applied recommendations.
- Add links from generated purchase orders back to source agent run/action.
- Add copy that makes recommendation basis clear.
- Review edge cases and failure states.

## 20. Future Python Optimization Service

Do not build this until Rails v1 produces real accepted/rejected recommendation data.

Possible future stack:

- FastAPI;
- PuLP;
- LangGraph;
- LangSmith.

Possible endpoints:

```text
POST /runs/{id}/execute
POST /optimize/rebalance
POST /recommendations/generate
```

Future responsibilities:

- constrained reorder optimization;
- multi-location allocation;
- inventory transfer suggestions;
- larger scenario planning.

Rails should remain the source of truth for merchants, approvals, purchase orders, and audit logs.

## 21. Risks and Mitigations

| Risk | Mitigation |
| --- | --- |
| Bad recommendations | Keep v1 rule-based, show reasoning, require approval. |
| Over-ordering | Enforce conservative quantity formula and optional min/max preferences. |
| Merchant distrust | Show exact inputs used: stock, threshold, lead time, supplier. |
| Workflow mistakes | Create draft POs only; never send automatically in v1. |
| Tenant leakage | Always load actions through current shop context. |
| Complexity creep | Defer forecasting, Python, optimization, and multi-agent orchestration. |

## 22. Resume-Truthful Outcome

After milestones 1-3, this can be described accurately as:

- AI inventory copilot for Shopify merchants;
- Rails-based recommendation engine;
- human-in-the-loop approval workflow;
- agent action tracking;
- automated draft purchase order generation;
- audit-logged recommendation lifecycle.

After a later optimization service exists, it can additionally be described as:

- hybrid Rails + Python optimization architecture;
- constrained inventory optimization using PuLP;
- external agent service integrated with Rails workflow state.
