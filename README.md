# StockPilot

Train an XGBoost sales forecast for **one item at a time**, using your own weekly sales. Import a CSV, see how accurately the model would have predicted recent weeks at each store, and get an estimate for the following week. The browser, training process and saved projects run on your computer.

## Run locally

Install **Node.js 20.9+ with npm** and **Python 3.11–3.14**. Windows setup installs a checksum-verified portable Redis queue server in the project. On macOS, install the trainer and queue dependencies with `brew install libomp valkey`. On Linux, install Valkey or Redis 6.2 or later (for example, `sudo apt install redis-server` on Ubuntu 24.04). Download and extract the StockPilot local release, or clone the repository. Open a terminal in the folder containing this README and run:

```sh
npm run setup
npm run dev
```

Open the [StockPilot forecast](http://127.0.0.1:3000/forecast). Use its sidebar to import sales, evaluate a forecast or reopen a saved project. Setup creates a Python environment in `.venv` and installs the JavaScript and CPU forecasting dependencies. Setup needs internet access. Importing, training, reopening a project and forecasting work offline after installation. To run a production build locally, use `npm run build` followed by `npm start`.

## Bring your sales history

Download the [example CSV](forecast_app/public/weekly-sales-template.csv) from the app or this repository. It contains fictional sales you can replace. Use one row per item, store and trading week.

| Column | What to enter |
| --- | --- |
| `week` | Monday starting the week, in `YYYY-MM-DD` format |
| `item` | A stable product name or ID, such as `Black long cardigan` |
| `store` | A stable store name or ID. A single store works. |
| `units_sold` | Whole units sold that week, including genuine zeros. The alias `units` also works. |
| `in_stock` | Optional. Use `false` for a week when availability constrained sales. Omitted flags assume the item was available. |

Include **at least eight consecutive, completed weeks per store**, ending on the same Monday. For transaction data, sum units by item, store and week first. Fill a confirmed zero-sales week with `0`. Investigate missing records before importing. The maximum CSV size is 1 MiB.

Choose **Import sales** in the sidebar and select the file. A one-item file goes straight into the forecast queue. For a file containing several items, choose the item to queue. Each import saves a project with that item's history, fitted model and forecasts. Reopen earlier imports from **Saved projects**. To update a forecast, import the full history with the newly completed weeks appended.

To try another XGBoost configuration, open **Training settings** before choosing the CSV. The defaults are **40 trees**, **maximum depth 2** and a **learning rate of 0.05**. These are fixed starting values. More trees add fitting steps, depth lets each tree learn more specific patterns, and the learning rate controls the size of each step. Import the same history with different settings to save another run. **Evaluation** shows the settings and error for each run. If you use those scores to choose settings, keep later weeks aside for a final check.

## Read the forecast

Open **Forecast** and select a store to see weekly predictions alongside actual sales. Under **Timeline**, the **Chart window** sets the first and last calculated week shown. Choose **All weeks** to restore the full chart.

Use **Forecast period** to predict a specific historical or future interval. Choose its first and last Monday, then select **Queue forecast**. StockPilot fits the model on the saved history before the start and uses its own predictions for later weeks, including any gap after the last recorded sale. The limit is 50,000 store-weeks per run, including gap weeks. A historical period lets you compare those predictions with recorded sales. Choose **Reset period** and rerun to return to the default forecast.

**Forecast queue** sits below the chart and its cards. It shows the active run, waiting runs in submission order and recent results. You can queue another period while a run is active, leave the page and return, or open a completed run to inspect its forecast. When a run includes comparison models, each model shows its own progress.

For the default run, the cards below the chart show that store’s next-week forecast, last observed sales and mean absolute error. Forecasts are expected units sold and can include decimals. Open **Evaluation** for the scored weeks and training details.

The model learns from the selected item across its stores. Inputs include store identity, recent sales, weeks since the first observation and calendar features. The default forecast tests the last half of the shortest store history, rounded down, up to eight weeks. It refits before each of those weeks, then uses all eligible history for the next-week estimate.

**Mean absolute error (MAE)** is the average distance in units between a forecast and the observed sales. An MAE of 2 means forecasts missed by two units on average. Weeks flagged out of stock are excluded as training targets and from MAE. Accuracy applies to this item, these stores and these dates. A short history may contain too little evidence to learn recurring holiday effects.

## Where your data lives

The Next.js server listens on the loopback interface. Your browser sends the CSV to the Python worker on that same computer. Queued inputs stay in the local data folder until processing finishes. Each saved project holds the selected item's normalized history, XGBoost model and results. Recent queue entries also retain the forecast snapshot for that particular run. You can reopen saved projects after restarting. The release includes a blank workspace and an optional synthetic CSV.

| Operating system | Default project folder |
| --- | --- |
| Windows | `%LOCALAPPDATA%\StockPilot\forecasts` |
| macOS | `~/Library/Application Support/StockPilot/forecasts` |
| Linux | `$XDG_DATA_HOME/stockpilot/forecasts`, or `~/.local/share/stockpilot/forecasts` |

Set `STOCKPILOT_DATA_DIR` before starting the app to choose another folder. Back up that folder to keep your projects. Delete a project's folder to remove its saved history, model and forecasts, then refresh the browser.

The local launcher starts an authenticated BullMQ broker bound to loopback and persists its queue under the forecast folder. You can use an existing local Redis 6.2+ or Valkey instance by setting `STOCKPILOT_REDIS_URL`. Configure persistence and the `noeviction` policy on an external broker to retain waiting jobs across restarts.
