# StockPilot

Forecast weekly sales for one item across its stores. Import a CSV, train XGBoost on that item's history, and compare predictions with actual sales for each store. The Next.js frontend, forecast queue, model, and saved projects run on your computer. An optional Shopify connection keeps a local copy of your shop's inventory.

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

Select a store on **Forecast** to see its sales and predictions. **Chart window** changes the dates shown. **Forecast period** sets the weeks to predict. **Queue forecast** runs that period using only history from before its start. The queue shows waiting, running, and completed forecasts.

The default run tests up to eight recent weeks and predicts the following week. **Evaluation** shows mean absolute error (MAE), the average miss in units, for weeks with stock available. To try a different model configuration, adjust tree count, depth, or learning rate under **Training settings** when importing.

To build a source ZIP for distribution, run `python scripts/package_forecast.py` from the repository root.

**Saved projects** reopens your history and results. Set `STOCKPILOT_DATA_DIR` to choose where projects and the queue are stored. By default they live under `%LOCALAPPDATA%\StockPilot\forecasts` on Windows, `~/Library/Application Support/StockPilot/forecasts` on macOS, or `~/.local/share/stockpilot/forecasts` on Linux (`XDG_DATA_HOME` is respected).

## Connect Shopify

Choose **Connect Shopify** on the import page to authorize a store and sync inventory through Shopify's Admin GraphQL API. Inventory quantities describe current stock. The forecasting model takes weekly units sold from the CSV above.

The connector is optional. To enable it, use Ruby 3.3+, PostgreSQL, a running Redis server, and a Shopify app. From `shopify/`, run `bundle install` and copy `.env.example` to `.env`. Fill in the Shopify client ID and secret, the PostgreSQL and Redis URLs, and your public HTTPS connector origin in `SHOPIFY_APP_URL`. Expose the connector port through your HTTPS tunnel. In `shopify.app.toml`, use the client ID of your Shopify app and replace the example URLs with your HTTPS origin followed by `/connect` and `/auth/shopify/callback`. From `shopify/`, publish the configuration to that app with `shopify app deploy` to register its product, uninstall, and privacy webhooks. [Shopify app configuration](https://shopify.dev/docs/apps/build/cli-for-apps/app-configuration)

For a new connector database, generate three separate Active Record encryption keys with `ruby -rsecurerandom -e "3.times { puts SecureRandom.hex(16) }"` and a session secret with `ruby -rsecurerandom -e "puts SecureRandom.hex(64)"`. Enter them in `.env`. When reusing an existing installation, use its database and original encryption keys so stored access tokens can still be read.

From `shopify/`, prepare the database and start the connector. Run the worker in a second terminal from the same directory.

```sh
bundle exec ruby bin/rails db:prepare
bundle exec ruby bin/rails server -b 127.0.0.1 -p 3001
```

```sh
bundle exec sidekiq -q shopify_inventory
```

The first connection queues an inventory sync. Use the connector to view inventory or request another sync. The frontend opens `http://127.0.0.1:3001/connect` by default. Set `NEXT_PUBLIC_SHOPIFY_CONNECT_URL` before starting or building Next.js to use a different connector address.
