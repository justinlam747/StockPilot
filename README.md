# StockPilot

Forecast weekly sales for one item across its stores. Import a CSV, train XGBoost on that item's history, and compare predictions with actual sales for each store. The Next.js frontend, forecast queue, model, and saved projects run on your computer. Transfers replays how moving stock between stores changes sales and shipping costs.

## Run the forecast app

Install Node.js 20.9 or newer with npm and Python 3.11–3.14. On Windows x64, setup installs a portable Redis server. On macOS, install the queue server and XGBoost runtime with `brew install valkey libomp`. On Linux, install Redis 6.2 or newer, or Valkey.

```sh
npm run setup
npm run dev
```

Open **Forecast**, then choose **Import sales** in the sidebar. For a production build, run `npm run build` followed by `npm start`. [Open the local frontend](http://127.0.0.1:3000/forecast)

## Forecast an item

Supply one row per item, store, and week, with at least eight consecutive completed weeks per store ending in the same week. Files can contain several items. Choose one per training run. The upload limit is 1 MiB. [Download the sample sales CSV](forecast_app/public/weekly-sales-template.csv)

| Column | Value |
| --- | --- |
| `week` | Monday of the trading week, in `YYYY-MM-DD` format |
| `item` | A consistent item name or ID |
| `store` | A consistent store name or ID |
| `units_sold` | Whole units sold that week. Enter `0` for confirmed zero sales. |
| `in_stock` | Optional. Use `false` if availability constrained sales that week. The default is `true`. |

Select a store on **Forecast** to compare recorded weekly sales with the XGBoost prediction in Chart.js. Weeks without recorded sales show only the forecast. Drag across weeks to zoom in, or use the **+** and **−** buttons around the inspected week. **Reset** restores all weeks. For exact dates, use **Timeline** → **Chart window**. **Forecast period** sets the weeks to predict. **Queue forecast** runs that period using only history from before its start. The queue shows waiting, running, and completed forecasts.

The default run tests up to eight recent weeks and predicts the following week. **Evaluation** shows mean absolute error (MAE), the average miss in units, for weeks with stock available. To try a different model configuration, adjust tree count, depth, or learning rate under **Training settings** when importing.

To build a source ZIP for distribution, run `python scripts/package_forecast.py` from the repository root.

**Saved projects** reopens your history and results. Set `STOCKPILOT_DATA_DIR` to choose where projects and the queue are stored. By default they live under `%LOCALAPPDATA%\StockPilot\forecasts` on Windows, `~/Library/Application Support/StockPilot/forecasts` on macOS, or `~/.local/share/stockpilot/forecasts` on Linux (`XDG_DATA_HOME` is respected).

## Simulate stock transfers

Open **Transfers** to replay the selected item week by week. The map arranges stores automatically and scales each storefront by units on hand. Add stores from the forecast, zoom the map, or pause on a week to inspect shipments and balances. A six-store cardigan example plays when there is no open forecast.

Opening stock covers 2, 0.5, 1.5 or 0.75 weeks of the first forecast, repeating in store order. Starting in week two, alternating groups of stores receive twice their previous weekly forecast every other week. Each week, donors keep nine days of predicted sales and send surplus to stores below seven days of cover. Shipments arrive before sales. Both scenarios use the same opening stock, deliveries and demand. Weeks with stock available use recorded sales. Weeks without recorded sales use forecast demand, and stock-constrained weeks use the higher of recorded sales and rounded forecast demand.

**Estimated net savings** are the additional units sold compared with running without transfers, multiplied by an assumed $12 contribution per unit, less $1 for each unit shipped. Moving stock can cost more than it recovers.
