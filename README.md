# StockPilot

A local, one-page inventory dashboard: see stores at a glance, watch stock move,
and act on predicted stockouts with forecast-based transfer recommendations.

StockPilot is moving from a broad Shopify app toward a focused inventory
intelligence showcase. The workflow is **inventory → demand forecast → stockout
warning → transfer → updated inventory**. Supplier management, purchase orders,
and a general-purpose AI copilot are outside the current dashboard scope.

## Run locally

Requires Python 3.12–3.14. From this repository on Windows:

```powershell
python -m venv .venv-dashboard
.venv-dashboard\Scripts\python.exe -m pip install -r local_dashboard/requirements.txt
.venv-dashboard\Scripts\python.exe -m local_dashboard.server
```

Open **http://127.0.0.1:8000**. No Shopify login, database, API keys, GPU, or cloud
resources are needed. After setup, `npm run dev` starts the same dashboard and
uses `.venv-dashboard`. Change ports with `npm run dev -- --port 8001`.
On macOS/Linux use `python3` to create the environment and
`.venv-dashboard/bin/python` for subsequent Python commands.

## The one-page dashboard

- **Store overview:** ten locations, fifty products per store, stock on hand, and
  store-product stockout counts. Select a store to filter the page.
- **Forecast updates:** real saved-model XGBoost inference for the next seven days
  across all 500 series. Inspect any series alongside the previous-week baseline.
  Refresh reruns inference; it does not retrain or invent new sales.
- **Inventory alerts:** projected stockout day, current stock, and seven-day demand.
  Search products/SKUs, filter urgent or empty positions, and inspect their forecasts.
- **Transfer recommendations:** move the same product from a surplus store to a
  shortage store. Suggestions explain quantities and the source safety-stock rule.
- **Stock history and movements:** daily network inventory chart plus a ledger of
  simulated sales, receipts, dispatched transfers, and received transfers.
- **GraphQL inventory sync:** local fixture inventory passes through a real typed
  GraphQL query at initialization and on each simulated day. UI reads and commands
  also use GraphQL. The local dashboard does not connect to Shopify.

Click **Advance one day** to simulate demand, record movements, receive transfers,
sync inventory, and refresh forecasts. **Play simulation** repeats every ten
seconds. **Reset simulation** restores the seeded scenario. State and audit events
are in memory; restarting the server resets them.

## Our XGBoost model and the 29% result

The dashboard includes the trained model and feature logic from `StockPilot-rebuild`,
using its `evaluation_20261116T165116Z` artifacts.

| Measured result | Value |
| --- | --- |
| Store-product series | 500 (10 stores × 50 products) |
| Evaluation period | Calendar year 2017 |
| Rolling backtest | 53 weekly origins; 52 complete seven-day windows |
| Previous-week weekly-total MAE | 26.66 units |
| XGBoost weekly-total MAE | 18.91 units |
| Relative reduction | **29.07%** |

Weekly error is measured after summing the seven predictions for each
store/product/origin, then averaging absolute error across those observations.
The baseline repeats the previous week's daily sales. Training uses only data
preceding each origin; recursive forecasts never use future observed sales.
See [the backtest summary](local_dashboard/artifacts/backtest-summary.md) and
[run metadata](local_dashboard/artifacts/backtest-run.json) for the original
protocol, results, and limits. The backtest was imported, not rerun during this refactor.

Features: categorical store/item, calendar fields, lags at 1/7/14/28/364 days,
and shifted 7/28-day rolling means. CPU inference uses the saved last-origin model;
there is no retraining in the demo.

## What is historical and what is simulated?

- **Historical:** the bundled 364-day sales context (2017-01-02 to 2017-12-31),
  trained model, and evaluation results. Sales may differ from unconstrained demand.
  This model is a backtest snapshot, not a production refit.
- **Simulated:** initial inventory, friendly store/product names, subsequent demand,
  receipts, transfers, stock history, and stockout scenarios. The simulation starts
  on 2018-01-01 to preserve the model's calendar context. Later demand is sampled
  around forecasts and is not evaluation evidence.
- **Projected:** stockout is the first day cumulative predicted demand reaches
  available stock plus next-day inbound units. These dates are point projections,
  not calibrated probabilities. Negative chart balances show unmet demand, not
  physically negative inventory.

Transfers reserve source stock immediately and arrive before sales on the next
simulated day. Donors retain seven forecast days plus two safety days. Suggestions
share donor budgets to prevent over-allocation. Inbound units count toward recipient
coverage after dispatch. Day-one shortages are conservatively excluded; replenishment
may be needed. Partial transfers may reduce a shortage without eliminating it.

The **29.07% forecast improvement is measured**. Stockout avoidance, transfer ROI,
and service-level improvements have not been measured. The source dataset has no
inventory or transfer-cost observations to establish those outcomes.

## Development

```powershell
.venv-dashboard\Scripts\python.exe -m pytest local_dashboard/tests -q
```

| Path | Purpose |
| --- | --- |
| `local_dashboard/engine.py` | Simulation, projections, alerts, recommendations, command audit |
| `local_dashboard/demand.py` | Existing feature construction and recursive forecasts |
| `local_dashboard/mock_sync.py` | Typed mock GraphQL inventory source |
| `local_dashboard/server.py` | Loopback-only HTTP server and GraphQL API |
| `local_dashboard/static/` | Responsive single-page dashboard; no frontend build |
| `local_dashboard/artifacts/` | Model, historical context, and backtest evidence |

Earlier Rails/Shopify work (`app/`) and the unfinished Remix/AI work (`web/`, `ai/`)
remain available. The dashboard does not depend on them.
`npm run dev:shopify` retains the earlier Shopify development command.
