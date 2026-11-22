"""Package the forecasting workspace for local use."""

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
    "forecast_app/app/transfers/page.jsx", "forecast_app/app/transfers/StoreMap.jsx",
    "forecast_app/app/transfers/simulation.mjs", "forecast_app/app/transfers/transfers.css",
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


def build(destination):
    destination.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(dir=destination.parent, delete=False) as tmp:
        temp_path = Path(tmp.name)
    try:
        with ZipFile(temp_path, "w") as archive:
            for name in sorted(FILES):
                info = ZipInfo("StockPilot/" + name)
                info.create_system = 3
                info.external_attr = 0o100644 << 16
                archive.writestr(info, (ROOT / name).read_bytes(), compress_type=ZIP_DEFLATED)
        os.replace(temp_path, destination)
    finally:
        temp_path.unlink(missing_ok=True)
    print(f"Packaged {len(FILES)} source files into {destination}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=ROOT / "dist" / "stockpilot-local.zip")
    build(parser.parse_args().output.resolve())
