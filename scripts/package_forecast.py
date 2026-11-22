"""Build the local trainer's source ZIP from an explicit release manifest."""

import argparse
import json
import os
import tempfile
from pathlib import Path
from zipfile import ZIP_DEFLATED, ZipFile, ZipInfo


ROOT = Path(__file__).resolve().parents[1]
FILES = (
    "README.md", "requirements.txt", "scripts/local.mjs",
    "forecast_app/next.config.mjs", "forecast_app/package.json",
    "forecast_app/app/layout.jsx", "forecast_app/app/page.jsx",
    "forecast_app/app/forecast/page.jsx", "forecast_app/app/api/forecast/route.js",
    "forecast_app/app/evaluation/page.jsx", "forecast_app/app/import/page.jsx",
    "forecast_app/app/projects/page.jsx", "forecast_app/app/charts.css",
    "forecast_app/app/ImportSales.jsx", "forecast_app/app/Results.jsx",
    "forecast_app/app/Workspace.jsx", "forecast_app/app/globals.css",
    "forecast_app/public/weekly-sales-template.csv",
    "stockpilot_local/__init__.py", "stockpilot_local/xgb.py",
    "stockpilot_local/parameters.py", "stockpilot_local/training_parameters.json",
    "stockpilot_local/store.py", "stockpilot_local/worker.py",
    "tests/test_stockpilot_xgb.py", "tests/test_forecast_worker.py",
    "tests/forecast-route.test.mjs", "tests/forecast-release.test.mjs",
)
PUBLIC_SCRIPTS = ("setup", "dev", "build", "start")
IGNORE = ".venv/\nnode_modules/\n.next/\n__pycache__/\n.pytest_cache/\n.stockpilot-data/\n.env*\n*.ubj\n"


def json_bytes(value):
    return (json.dumps(value, indent=2, ensure_ascii=False) + "\n").encode()


def package_files():
    package = json.loads((ROOT / "package.json").read_text(encoding="utf-8"))
    public = {key: package[key] for key in ("name", "private", "engines", "dependencies")}
    public["scripts"] = {key: package["scripts"][key] for key in PUBLIC_SCRIPTS}
    lock = json.loads((ROOT / "package-lock.json").read_text(encoding="utf-8"))
    # npm marks packages exclusively reachable through a development dependency.
    lock["packages"] = {key: pkg for key, pkg in lock["packages"].items() if not pkg.get("dev")}
    lock["packages"][""].pop("devDependencies", None)
    return {"package.json": json_bytes(public), "package-lock.json": json_bytes(lock)}


def build(destination):
    destination.parent.mkdir(parents=True, exist_ok=True)
    contents = {name: (ROOT / name).read_bytes() for name in FILES}
    contents.update(package_files())
    contents[".gitignore"] = IGNORE.encode()
    with tempfile.NamedTemporaryFile(dir=destination.parent, delete=False) as tmp:
        temp_path = Path(tmp.name)
    try:
        with ZipFile(temp_path, "w") as archive:
            for name, data in sorted(contents.items()):
                info = ZipInfo("StockPilot/" + name)
                info.create_system = 3
                info.external_attr = 0o100644 << 16
                archive.writestr(info, data, compress_type=ZIP_DEFLATED)
        os.replace(temp_path, destination)
    finally:
        temp_path.unlink(missing_ok=True)
    print(f"Packaged {len(contents)} source files into {destination}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=ROOT / "dist" / "stockpilot-local.zip")
    build(parser.parse_args().output.resolve())
