"""Read one local CSV request from stdin and write one JSON response to stdout."""

import csv
import io
import json
import re
import sys
from datetime import date

from . import store
from .history import group_rows, historical_period, history_range
from .parameters import FIELDS, parse_window, validate_parameters
from .progress import emit, model_step


REQUIRED = {"week", "item", "store", "units_sold"}
STOCK_VALUES = {"true": True, "false": False, "1": True, "0": False}
MAX_UPLOAD_BYTES = 1024 * 1024


def parse_row(raw, line, has_stock):
    if None in raw or any(value is None for value in raw.values()):
        raise ValueError(f"Row {line} has a different number of fields from the header.")
    item, store = raw["item"].strip(), raw["store"].strip()
    if not item or not store:
        raise ValueError(f"Row {line} needs both an item and a store.")
    week = raw["week"].strip()
    try:
        start = date.fromisoformat(week)
        if start.isoformat() != week or start.weekday() != 0:
            raise ValueError
    except ValueError:
        raise ValueError(f"Row {line} needs a Monday week start in YYYY-MM-DD format.") from None
    units = raw["units_sold"].strip()
    if not re.fullmatch(r"[0-9]{1,10}", units):
        raise ValueError(f"Row {line} needs whole, nonnegative units_sold. Use 0 for a confirmed zero-sales week.")
    stock = raw["in_stock"].strip().lower() if has_stock else "true"
    if stock not in STOCK_VALUES:
        raise ValueError(f"Row {line} needs true or false in the in_stock column.")
    return {"week": week, "item": item, "store": store, "units_sold": int(units), "in_stock": STOCK_VALUES[stock]}


def parse_csv(text, *, upload=True):
    if not isinstance(text, str) or not text.strip():
        raise ValueError("Select a CSV file containing weekly sales.")
    if upload and len(text.encode("utf-8")) > MAX_UPLOAD_BYTES:
        raise ValueError("The CSV exceeds the 1 MiB upload limit.")
    reader = csv.DictReader(io.StringIO(text.removeprefix("\ufeff"), newline=""), strict=True)
    headers = [name.strip().lower() for name in (reader.fieldnames or [])]
    if "units" in headers:
        if "units_sold" in headers:
            raise ValueError("Choose either units_sold or units, so the sales column is unambiguous.")
        headers = ["units_sold" if name == "units" else name for name in headers]
    missing = REQUIRED.difference(headers)
    if missing:
        raise ValueError("Missing CSV columns: " + ", ".join(sorted(missing)) + ".")
    if len(headers) != len(set(headers)):
        raise ValueError("The CSV contains duplicate column names.")
    reader.fieldnames = headers
    by_item, seen = {}, set()
    for raw in reader:
        row = parse_row(raw, reader.line_num, "in_stock" in headers)
        key = row["week"], row["item"], row["store"]
        if key in seen:
            raise ValueError(f"Row {reader.line_num} repeats an item, store and week. Aggregate the units in a single row.")
        seen.add(key)
        by_item.setdefault(row["item"], []).append(row)
    if not by_item:
        raise ValueError("The CSV has a header but no weekly sales records.")
    return by_item, "in_stock" in headers


def read_project(project_id, comparisons, *, activate=True):
    saved = store.restore(project_id, activate=activate)
    if not saved["result"]:
        return saved
    bounds = saved["result"].get("historyRange", {})
    if "recommendedStart" not in bounds:
        text, item, _ = store.saved_training_input(saved["projectId"])
        by_item, _ = parse_csv(text, upload=False)
        bounds = history_range(group_rows(by_item[item]))
    if comparisons:
        saved = comparisons.restore(saved)
    saved["result"]["historyRange"] = bounds
    return saved


def training_inputs(request, op):
    if op == "rerun":
        text, item, settings = store.saved_training_input(request.get("projectId"))
        parameters = {key: settings[key] for key in FIELDS if key in settings}
    else:
        text, item, parameters = request.get("csv"), request.get("item"), request.get("parameters", {})
    validate_parameters(parameters)
    by_item, stock_reported = parse_csv(text, upload=op != "rerun")
    return by_item, item, parameters, stock_reported


def item_choice(by_item, item):
    items = [{"id": item, "name": item} for item in sorted(by_item)]
    if item is None and len(items) > 1:
        return {"items": items, "selectionRequired": True}
    if item is None:
        item = items[0]["id"]
    if not isinstance(item, str) or item not in by_item:
        raise ValueError("The selected item does not exist in this CSV.")
    return {"item": item, "items": items}


def fit_and_save(rows, parameters, stock_reported, period, peers, comparisons, *, activate, report):
    with model_step("xgboost", report):
        from .window import train_window
        result, model = train_window(rows, period, parameters=parameters)
    result["source"]["availability"] = "reported" if stock_reported else "assumed"
    overlay = comparisons.forecast(result, rows, peers, report=report) if peers else None
    saved = store.save(rows, result, model, stock_reported, activate=activate and not comparisons)
    if comparisons:
        if activate:
            comparisons.publish(saved["projectId"], overlay)
            store.mark_current(store.data_dir(), saved["projectId"])
        if overlay is not None:
            saved["result"] = overlay
    return saved


def activate_snapshot(project_id, result, comparisons):
    folder = store.project_directory(project_id)
    if result is not None and comparisons:
        overlay = result if len(result["models"]) > 1 or result.get("modelWarnings") else None
        comparisons.publish(project_id, overlay)
    store.mark_current(folder.parent, project_id)
    return {"projects": store.project_list(folder.parent)}


def process_request(request, comparisons=None):
    if not isinstance(request, dict):
        raise ValueError("Expected a JSON object.")
    op = request.get("op", "train")
    if op == "capabilities":
        return {"peerModels": comparisons.models() if comparisons else []}
    if op == "read":
        return read_project(request.get("id"), comparisons, activate=request.get("activate", True))
    if op == "activate":
        return activate_snapshot(request.get("id"), request.get("comparisonResult"), comparisons)
    action = request.get("action") if op == "inspect" else op
    if action not in ("train", "rerun"):
        raise ValueError("Unknown forecast operation.")
    peers = request.get("peers", [])
    if comparisons:
        comparisons.validate(peers)
    elif peers != []:
        raise ValueError("Only XGBoost is available in this installation.")
    period = parse_window(request.get("forecastStart"), request.get("forecastEnd"))
    by_item, item, parameters, stock_reported = training_inputs(request, action)
    choice = item_choice(by_item, item)
    if choice.get("selectionRequired"):
        return choice
    rows = by_item[choice["item"]]
    if op == "inspect":
        groups = group_rows(rows)
        historical_period(history_range(groups), period, len(groups))
        return {"item": choice["item"]}
    saved = fit_and_save(rows, parameters, stock_reported, period, peers, comparisons,
                         activate=request.get("activate", True), report=emit if request.get("progress") else None)
    return {"items": choice["items"], **saved}


def main(comparisons=None):
    try:
        response = process_request(json.load(sys.stdin), comparisons)
    except store.UnknownProject as exc:
        response = {"status": 404, "error": str(exc)}
    except (ValueError, csv.Error) as exc:
        response = {"status": 422, "error": str(exc)}
    except OverflowError:
        response = {"status": 422, "error": "The supplied dates exceed the range supported for weekly forecasts."}
    except ImportError:
        response = {"status": 503, "error": "Install the local Python dependencies from requirements.txt to train XGBoost."}
    except OSError:
        response = {"status": 503, "error": "Cannot access local forecast files. Check the data folder permissions or set STOCKPILOT_DATA_DIR."}
    print(json.dumps(response, allow_nan=False, separators=(",", ":")))


if __name__ == "__main__":
    main()
