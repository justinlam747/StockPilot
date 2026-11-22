"""Walk-forward evaluation and next-week sales forecasts for one item across stores."""

import json
import math
from datetime import date, timedelta
from statistics import fmean

import numpy as np
from scipy.sparse import csr_matrix
from xgboost import XGBRegressor

from .parameters import XGB_OPTIONS, validate_parameters

WEEK = timedelta(days=7)
FEATURES = ["Previous 1–3 weeks", "Up to 3-week average", "Weeks since first record",
            "Annual seasonality", "Christmas window", "Store identity"]


def group_rows(rows):
    if not rows or len({r["item"] for r in rows}) != 1:
        raise ValueError("Include exactly one item per forecast.")
    groups = {}
    for row in rows:
        if not all(isinstance(row[key], str) and row[key].strip() for key in ("store", "item")):
            raise ValueError("Each observation needs an item and a store.")
        week = date.fromisoformat(row["week"])
        if week.isoformat() != row["week"] or week.weekday() != 0 or week > date.max - WEEK:
            raise ValueError("Use a Monday in YYYY-MM-DD format with room for a following week.")
        units, available = row["units_sold"], row.get("in_stock", True)
        if type(units) is not int or not 0 <= units <= 9_999_999_999 or type(available) is not bool:
            raise ValueError("Each observation needs nonnegative whole units (up to 10 digits) and a true/false in_stock flag.")
        group = groups.setdefault(row["store"], {})
        if week in group:
            raise ValueError(f"Duplicate week for {row['store']}: {week}.")
        group[week] = (units, available)
    for store, group in groups.items():
        if (max(group) - min(group)) // WEEK + 1 != len(group):
            raise ValueError(f"Missing week for {store}. Supply every weekly observation, including genuine zeros.")
    if len({max(group) for group in groups.values()}) != 1:
        raise ValueError("All stores must end on the same observed week.")
    return groups


def features(week, age, group):
    lags = [group[week - n * WEEK][0] if n <= min(age, len(group)) else np.nan for n in (1, 2, 3)]
    observed = [x for x in lags if math.isfinite(x)]
    angle = 2 * math.pi * (week.isocalendar().week - 1) / 52.18
    christmas = date(week.year, 12, 25)
    christmas_week = christmas - timedelta(days=christmas.weekday())
    return [*lags, fmean(observed) if observed else np.nan, age,
            math.sin(angle), math.cos(angle), float(0 <= (christmas_week - week).days <= 14)]


def training_examples(groups, stores):
    samples = []
    for index, store in enumerate(stores):
        group = groups[store]
        first = min(group)
        for age in range(len(group) + 1):
            week = first + age * WEEK
            actual, available = group.get(week, (None, None))
            samples.append(dict(store=store, week=week, x=features(week, age, group), store_index=index,
                                actual=actual, available=available, trainable=age > 0 and bool(available)))
    return samples


def model_input(samples, store_count):
    # Keep measured zeros as explicit values. Only the store indicators are sparse.
    width = len(samples[0]["x"])
    values = np.array([[*s["x"], 1] for s in samples], dtype=np.float32)
    indices = np.array([[*range(width), width + s["store_index"]] for s in samples], dtype=np.int32)
    indptr = np.arange(0, values.size + 1, width + 1, dtype=np.int32)
    return csr_matrix((values.ravel(), indices.ravel(), indptr), shape=(len(samples), width + store_count))


def predict_frame(tree, targets, origin, store_count):
    predictions = tree.predict(model_input(targets, store_count))
    cells = [dict(id=row["store"], actual=row["actual"], available=row["available"],
                  forecasts={"xgboost": round(max(0.0, float(pred)), 6)})
             for row, pred in zip(targets, predictions, strict=True)]
    return {"week": origin.isoformat(), "stores": cells}


def fit_week(samples, origin, store_count, options=XGB_OPTIONS):
    train = [s for s in samples if s["trainable"] and s["week"] < origin]
    if not train:
        raise ValueError("Too few prior in-stock weeks with sales history to fit the first forecast.")
    tree = XGBRegressor(**options)
    tree.fit(model_input(train, store_count), [s["actual"] for s in train])
    targets = [s for s in samples if s["week"] == origin]
    return predict_frame(tree, targets, origin, store_count), len(train), tree


def forecast_origins(groups, holdout_start):
    shortest = min(map(len, groups.values()))
    if shortest < 8:
        raise ValueError("Include at least eight consecutive weeks at each store.")
    last = max(next(iter(groups.values())))
    start = holdout_start or last - (min(8, shortest // 2) - 1) * WEEK
    if start.weekday() != 0 or start > last or any(start <= min(g) for g in groups.values()):
        raise ValueError("The holdout must start on a Monday following observed sales at every store.")
    return [start + n * WEEK for n in range((last - start) // WEEK + 2)]


def score_weeks(weeks, stores):
    observed = [cell for frame in weeks for cell in frame["stores"]]
    scores = []
    for store in [None, *stores]:
        cells = [cell for cell in observed if store is None or cell["id"] == store]
        errors = [abs(cell["forecasts"]["xgboost"] - cell["actual"]) for cell in cells if cell["available"]]
        scores.append(dict(store=store, count=len(errors), excluded=len(cells) - len(errors),
                           mae={"xgboost": round(fmean(errors), 6) if errors else None}))
    return scores


def train_item(rows, *, holdout_start=None, parameters=None):
    """Refit at each test week, then return the evaluation and a native saveable final estimator."""
    options = XGB_OPTIONS.copy()
    if parameters is not None:
        validate_parameters(parameters)
        options.update(parameters)
    groups = group_rows(rows)
    stores = sorted(groups)
    samples = training_examples(groups, stores)
    origins = forecast_origins(groups, holdout_start)
    runs = [fit_week(samples, origin, len(stores), options)[:2] for origin in origins[:-1]]
    weeks = [frame for frame, count in runs]
    next_week, final_count, final_tree = fit_week(samples, origins[-1], len(stores), options)
    item = rows[0]["item"]
    metadata = dict(version=1, item=item, stores=stores, trainedThrough=(origins[-1] - WEEK).isoformat(),
                    firstWeeks={store: min(groups[store]).isoformat() for store in stores})
    final_tree.get_booster().set_attr(stockpilot=json.dumps(metadata, ensure_ascii=True))
    result = {
        "item": item, "source": {"name": "Uploaded weekly sales", "kind": "upload"},
        "stores": [{"id": store, "name": store} for store in stores],
        "models": [{"id": "xgboost", "name": "XGBoost"}],
        "weeks": weeks, "scores": score_weeks(weeks, stores), "next": next_week,
        "training": {"initialRows": runs[0][1], "finalRows": final_count, "holdoutWeeks": len(weeks),
                     "features": FEATURES, "storeOrder": stores, "parameters": options,
                     "scope": "XGBoost shares one model across stores for this item and refits before each forecast."},
    }
    return result, final_tree


def predict_next(model, rows, store_order=None):
    """Use a saved estimator and the item's latest complete weekly history to forecast one week."""
    groups = group_rows(rows)
    encoded = model.get_booster().attr("stockpilot")
    if not encoded:
        raise ValueError("Load a StockPilot weekly model to forecast with this history.")
    metadata = json.loads(encoded)
    stores = metadata["stores"]
    if metadata.get("version") != 1 or rows[0]["item"] != metadata["item"]:
        raise ValueError("Sales history must match the item used to train this model.")
    if sorted(groups) != stores or (store_order is not None and list(store_order) != stores):
        raise ValueError("Store identities and feature order must match the saved model.")
    last = max(groups[stores[0]])
    if last.isoformat() < metadata["trainedThrough"]:
        raise ValueError("Sales history must reach the last week used to train this model.")
    next_week = last + WEEK
    targets = []
    for i, store in enumerate(stores):
        first = date.fromisoformat(metadata["firstWeeks"][store])
        group = groups[store]
        if min(group) < first or len(group) < 3:
            raise ValueError("Provide at least three recent weeks per store within the item's recorded history.")
        targets.append(dict(store=store, actual=None, available=None, store_index=i,
                            x=features(next_week, (next_week - first) // WEEK, group)))
    return predict_frame(model, targets, next_week, len(stores))
