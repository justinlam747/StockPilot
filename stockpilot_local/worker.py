"""Read one local CSV request from stdin and write one JSON response to stdout."""

import csv
import io
import json
import re
import sys
from datetime import date

from . import store
from .parameters import validate_parameters


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


def parse_csv(text):
    if not isinstance(text, str) or not text.strip():
        raise ValueError("Select a CSV file containing weekly sales.")
    if len(text.encode("utf-8")) > MAX_UPLOAD_BYTES:
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


def process_request(request):
    if not isinstance(request, dict):
        raise ValueError("Expected a JSON object.")
    op = request.get("op", "train")
    if op == "read":
        return store.restore(request.get("id"))
    if op != "train":
        raise ValueError("Unknown forecast operation.")
    parameters = request.get("parameters", {})
    validate_parameters(parameters)
    by_item, stock_reported = parse_csv(request.get("csv"))
    items = [{"id": item, "name": item} for item in sorted(by_item)]
    item = request.get("item")
    if item is None and len(items) > 1:
        return {"items": items, "selectionRequired": True}
    if item is None:
        item = items[0]["id"]
    if not isinstance(item, str) or item not in by_item:
        raise ValueError("The selected item does not exist in this CSV.")
    # Listing local projects and inspecting a CSV don't require loading the ML runtime.
    from .xgb import train_item

    rows = by_item[item]
    result, model = train_item(rows, parameters=parameters)
    result["source"]["availability"] = "reported" if stock_reported else "assumed"
    return {"items": items, **store.save(rows, result, model, stock_reported)}


def main():
    try:
        response = process_request(json.load(sys.stdin))
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
