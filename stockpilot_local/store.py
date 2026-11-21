"""Publish independent, complete forecast snapshots in the user's local data folder."""

import csv
import hashlib
import io
import json
import os
import re
import sys
import tempfile
from datetime import datetime, timezone
from pathlib import Path


PROJECT_ID = re.compile(r"[0-9a-f]{64}")


class UnknownProject(ValueError):
    """The requested project ID has no saved forecast."""


def data_dir():
    configured = os.environ.get("STOCKPILOT_DATA_DIR")
    if configured:
        return Path(configured).expanduser().resolve()
    if sys.platform == "win32":
        base = Path(os.environ.get("LOCALAPPDATA") or Path.home() / "AppData" / "Local")
        return base / "StockPilot" / "forecasts"
    if sys.platform == "darwin":
        return Path.home() / "Library" / "Application Support" / "StockPilot" / "forecasts"
    return Path(os.environ.get("XDG_DATA_HOME") or Path.home() / ".local" / "share") / "stockpilot" / "forecasts"


def json_text(value):
    return json.dumps(value, ensure_ascii=False, allow_nan=False, sort_keys=True, separators=(",", ":"))


def normalized_csv(rows, stock_reported):
    columns = ["week", "item", "store", "units_sold"]
    if stock_reported:
        columns.append("in_stock")
    output = io.StringIO(newline="")
    writer = csv.DictWriter(output, fieldnames=columns, extrasaction="ignore")
    writer.writeheader()
    for row in sorted(rows, key=lambda r: (r["week"], r["store"])):
        writer.writerow(row)
    return output.getvalue()


def read_saved_json(path):
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (ValueError, OSError) as exc:
        raise OSError("The saved project cannot be read.") from exc


def project_list(root):
    if not root.exists():
        return []
    projects = []
    for folder in root.iterdir():
        if PROJECT_ID.fullmatch(folder.name) and not folder.is_symlink() and folder.is_dir():
            metadata = read_saved_json(folder / "project.json")
            if not isinstance(metadata, dict) or metadata.get("id") != folder.name:
                raise OSError("The saved project metadata is invalid.")
            if not all(isinstance(metadata.get(k), str) for k in ("item", "savedAt")):
                raise OSError("The saved project metadata is incomplete.")
            projects.append(metadata)
    return sorted(projects, key=lambda entry: (entry["savedAt"], entry["id"]), reverse=True)


def mark_current(root, project_id):
    # The marker may be read by another request while this one finishes.
    with tempfile.TemporaryDirectory(prefix=".active-", dir=root) as temp:
        marker = Path(temp) / "current"
        marker.write_text(project_id, encoding="ascii")
        os.replace(marker, root / "current")


def restore(project_id=None):
    root = data_dir()
    if project_id is not None and (not isinstance(project_id, str) or not PROJECT_ID.fullmatch(project_id)):
        raise ValueError("The saved project ID is invalid.")
    projects = project_list(root)
    by_id = {project["id"]: project for project in projects}
    explicit_selection = project_id is not None
    if not explicit_selection:
        if not projects:
            return {"projects": [], "projectId": None, "savedAt": None, "result": None}
        marker = root / "current"
        current = marker.read_text(encoding="ascii") if marker.is_file() else None
        project_id = current if current in by_id else projects[0]["id"]
    elif project_id not in by_id:
        raise UnknownProject("The saved forecast was not found.")
    result = read_saved_json(root / project_id / "forecast.json")
    if explicit_selection:
        mark_current(root, project_id)
    return {"projects": projects, "projectId": project_id, "savedAt": by_id[project_id]["savedAt"], "result": result}


def save(rows, result, model, stock_reported):
    root = data_dir()
    root.mkdir(mode=0o700, parents=True, exist_ok=True)
    history = normalized_csv(rows, stock_reported).encode("utf-8")
    forecast = json_text(result).encode("utf-8")
    digest = hashlib.sha256(history + b"\x00" + forecast).hexdigest()
    target = root / digest
    if target.is_symlink():
        raise OSError("Invalid project directory.")
    if not target.is_dir():
        with tempfile.TemporaryDirectory(prefix=".upload-", dir=root) as staging:
            pending = Path(staging) / digest
            pending.mkdir(mode=0o700)
            (pending / "history.csv").write_bytes(history)
            (pending / "forecast.json").write_bytes(forecast)
            model.save_model(pending / "model.ubj")
            metadata = {"id": digest, "item": result["item"], "savedAt": datetime.now(timezone.utc).isoformat()}
            (pending / "project.json").write_text(json_text(metadata), encoding="utf-8")
            try:
                pending.rename(target)
            except OSError:
                # An identical upload can finish in another server process.
                if target.is_symlink() or not target.is_dir():
                    raise
    return restore(digest)
