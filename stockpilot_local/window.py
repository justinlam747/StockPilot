"""Fit a single sales model using only observations before the selected Monday."""

import json
import math

from xgboost import XGBRegressor

from .history import MAX_STORE_WEEKS, WEEK, group_rows, historical_period, history_range
from .parameters import ForecastRangeError, XGB_OPTIONS, parse_window, validate_parameters
from .xgb import FEATURES, features, model_input, predict_frame, score_weeks, training_examples


def fit_before(groups, start, end, options):
    history = {}
    baseline = {}
    for store, group in sorted(groups.items()):
        prior = {week: sale for week, sale in sorted(group.items()) if week < start}
        observed = [units for units, _ in prior.values() if math.isfinite(units)]
        if observed:
            history[store] = prior
            baseline[store] = observed[-1]
    display_size = ((end - start) // WEEK + 1) * len(groups)
    steps = sum((end - max(group)) // WEEK for group in history.values())
    if max(display_size, steps) > MAX_STORE_WEEKS:
        raise ForecastRangeError("Choose a shorter range or move it closer to the sales history "
                                 "(50,000 store-weeks per run, including gaps).")
    samples = [row for row in training_examples(history, list(history)) if row["trainable"]]
    if not samples:
        raise ForecastRangeError("Choose a start week after an eligible in-stock training week.")
    model = XGBRegressor(**options)
    model.fit(model_input(samples, len(history)), [row["actual"] for row in samples])
    return model, history, baseline


def project(model, history, start, end):
    # A shop whose records stop early needs recursive lags across the gap before the requested window.
    stores = [(store, min(group), max(group)) for store, group in history.items()]
    first = min(last for _, _, last in stores) + WEEK
    predictions = {}
    for step in range((end - first) // WEEK + 1):
        week = first + step * WEEK
        targets = [dict(store=store, store_index=index, actual=None, available=None,
                        x=features(week, (week - launch) // WEEK, history[store]))
                   for index, (store, launch, last) in enumerate(stores) if week > last]
        for cell in predict_frame(model, targets, week, len(stores))["stores"]:
            value = cell["forecasts"]["xgboost"]
            history[cell["id"]][week] = (value, False)
            if week >= start:
                predictions[cell["id"], week] = value
    return predictions


def train_window(rows, period, parameters=None):
    """Fit through the week before the historical evaluation period and forecast recursively."""
    if parameters is not None:
        validate_parameters(parameters)
    options = {**XGB_OPTIONS, **(parameters or {})}
    groups = group_rows(rows)
    bounds = history_range(groups)
    stores = sorted(groups)
    start, end = historical_period(bounds, period, len(stores))
    model, history, _ = fit_before(groups, start, end, options)
    metadata = dict(version=1, item=rows[0]["item"], stores=list(history),
                    trainedThrough=max(max(group) for group in history.values()).isoformat(),
                    firstWeeks={store: min(group).isoformat() for store, group in history.items()})
    model.get_booster().set_attr(stockpilot=json.dumps(metadata, ensure_ascii=True))
    count = sum(sum(available for _, available in list(group.values())[1:]) for group in history.values())
    predictions = project(model, history, start, end)
    weeks = []
    for offset in range((end - start) // WEEK + 1):
        week = start + offset * WEEK
        cells = []
        for store in stores:
            actual, available = groups[store].get(week, (None, None))
            cells.append(dict(id=store, actual=actual, available=available,
                              forecasts={"xgboost": predictions.get((store, week))}))
        weeks.append(dict(week=week.isoformat(), stores=cells))
    result = {
        "item": rows[0]["item"], "source": {"kind": "upload", "name": "Uploaded weekly sales"},
        "stores": [{"id": store, "name": store} for store in stores],
        "models": [{"id": "xgboost", "name": "XGBoost"}],
        "weeks": weeks, "scores": score_weeks(weeks, stores), "next": None,
        "historyRange": bounds, "forecastRange": {"start": start.isoformat(), "end": end.isoformat()},
        "training": {"initialRows": count, "finalRows": count, "holdoutWeeks": len(weeks),
                     "features": FEATURES, "storeOrder": list(history), "parameters": options,
                     "scope": "One fit on pre-period sales. Later weeks use the model's own predicted sales as lags."},
    }
    return result, model
