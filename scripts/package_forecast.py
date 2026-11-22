"""Package the forecasting workspace and optional Shopify connector for local use."""

import argparse
import os
import tempfile
from pathlib import Path
from zipfile import ZIP_DEFLATED, ZipFile, ZipInfo


ROOT = Path(__file__).resolve().parents[1]
FILES = (
    ".gitignore", "README.md", "requirements.txt", "package.json", "package-lock.json",
    "scripts/local.mjs", "scripts/package_forecast.py", "scripts/queue-broker.mjs", "scripts/setup-redis.py",
    "forecast_app/next.config.mjs", "forecast_app/package.json",
    "forecast_app/instrumentation.js", "forecast_app/server/redis-connection.mjs",
    "forecast_app/server/forecast-queue.mjs", "forecast_app/server/forecast-worker.mjs",
    "forecast_app/server/forecast-job-files.mjs",
    "forecast_app/app/layout.jsx", "forecast_app/app/page.jsx",
    "forecast_app/app/forecast/page.jsx", "forecast_app/app/api/forecast/route.js",
    "forecast_app/app/evaluation/page.jsx", "forecast_app/app/import/page.jsx",
    "forecast_app/app/projects/page.jsx", "forecast_app/app/charts.css",
    "forecast_app/app/ImportSales.jsx", "forecast_app/app/Results.jsx",
    "forecast_app/app/ForecastControls.jsx", "forecast_app/app/ForecastQueue.jsx",
    "forecast_app/app/useForecastQueue.js", "forecast_app/app/queue.css",
    "forecast_app/app/Workspace.jsx", "forecast_app/app/globals.css",
    "forecast_app/public/weekly-sales-template.csv",
    "stockpilot_local/__init__.py", "stockpilot_local/xgb.py",
    "stockpilot_local/parameters.py", "stockpilot_local/training_parameters.json", "stockpilot_local/progress.py",
    "stockpilot_local/store.py", "stockpilot_local/worker.py", "stockpilot_local/window.py",
    "tests/test_forecast_worker.py",
    "tests/forecast-route.test.mjs", "tests/forecast-release.test.mjs", "tests/forecast-queue.test.mjs",
    "tests/queue-broker.test.mjs",
)
SHOPIFY_FILES = (
    ".env.example", "Gemfile", "Gemfile.lock", "Rakefile", "config.ru", "shopify.app.toml", "bin/rails",
    "app/controllers/connections_controller.rb", "app/controllers/webhooks_controller.rb",
    "app/jobs/inventory_sync_job.rb", "app/models/inventory_snapshot.rb", "app/models/product.rb",
    "app/models/shop.rb", "app/models/variant.rb", "app/services/shopify/graphql_client.rb",
    "app/services/shopify/inventory_fetcher.rb", "app/views/connections/show.html.erb",
    "config/application.rb", "config/boot.rb", "config/database.yml", "config/environment.rb",
    "config/initializers/credentials.rb", "config/initializers/omniauth.rb",
    "config/initializers/sidekiq.rb", "config/puma.rb", "config/routes.rb",
    "db/migrate/20261121000000_prepare_shopify_connector.rb",
)


def build(destination):
    destination.parent.mkdir(parents=True, exist_ok=True)
    paths = sorted([*FILES, *("shopify/" + file for file in SHOPIFY_FILES)])
    with tempfile.NamedTemporaryFile(dir=destination.parent, delete=False) as tmp:
        temp_path = Path(tmp.name)
    try:
        with ZipFile(temp_path, "w") as archive:
            for name in paths:
                info = ZipInfo("StockPilot/" + name)
                info.create_system = 3
                info.external_attr = (0o100755 if name == "shopify/bin/rails" else 0o100644) << 16
                archive.writestr(info, (ROOT / name).read_bytes(), compress_type=ZIP_DEFLATED)
        os.replace(temp_path, destination)
    finally:
        temp_path.unlink(missing_ok=True)
    print(f"Packaged {len(paths)} source files into {destination}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=ROOT / "dist" / "stockpilot-local.zip")
    build(parser.parse_args().output.resolve())
