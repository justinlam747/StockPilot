# StockPilot

Train an XGBoost sales forecast for **one item at a time**, using your own weekly sales. Import a CSV, see how accurately the model would have predicted recent weeks at each store, and get an estimate for the following week. The browser, training process and saved projects run on your computer.

## Run locally

Install **Node.js 20.9+ with npm** and **Python 3.11–3.14**. On macOS, install the OpenMP runtime with `brew install libomp`. Download and extract the StockPilot local release, or clone the repository. Open a terminal in the folder containing this README and run:

```sh
npm run setup
npm run dev
```

Open **[127.0.0.1:3000](http://127.0.0.1:3000)**. Setup creates a Python environment in `.venv` and installs the JavaScript and CPU forecasting dependencies. Setup needs internet access. Importing, training, reopening a project and forecasting work offline after installation. To run a production build locally, use `npm run build` followed by `npm start`.

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

Import the file in the browser. A one-item file trains immediately. For a file containing several items, choose the item to train. Each import saves a project with that item's history, fitted model and forecasts. To update a forecast, import the full history with the newly completed weeks appended.

## Read the forecast

Each store has a next-week estimate in **units sold** and a chart of the predictions made for recent weeks alongside recorded sales. Decimal forecasts represent expected unit sales. Stock on hand and transfer quantities measure different things.

The model learns from the selected item across its stores. Inputs include store identity, recent sales, weeks since the first observation and calendar features. For each historical prediction, it fits on earlier eligible weeks, then compares the prediction with the actual result. It tests the last half of the shortest store history, rounded down, up to eight weeks. The final fit uses all eligible history for the next-week estimate.

**Mean absolute error (MAE)** is the average distance in units between a forecast and the observed sales. An MAE of 2 means forecasts missed by two units on average. Weeks flagged out of stock are excluded as training targets and from MAE. Accuracy applies to this item, these stores and these dates. A short history may contain too little evidence to learn recurring holiday effects.

## Where your data lives

The Next.js server listens on the loopback interface. Your browser sends the CSV to the Python worker on that same computer. Only the selected item's normalized history is saved, along with its XGBoost model and results. You can reopen saved projects after restarting. The release includes a blank workspace and an optional synthetic CSV.

| Operating system | Default project folder |
| --- | --- |
| Windows | `%LOCALAPPDATA%\StockPilot\forecasts` |
| macOS | `~/Library/Application Support/StockPilot/forecasts` |
| Linux | `$XDG_DATA_HOME/stockpilot/forecasts`, or `~/.local/share/stockpilot/forecasts` |

Set `STOCKPILOT_DATA_DIR` before starting the app to choose another folder. Back up that folder to keep your projects. Delete a project's folder to remove its saved history, model and forecasts, then refresh the browser.
