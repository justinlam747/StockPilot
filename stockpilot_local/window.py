"""Fit a single sales model using only observations before the selected Monday."""

import json
import math
from datetime import date

from xgboost import XGBRegressor

from .parameters import XGB_OPTIONS, validate_parameters
from .xgb import FEATURES, WEEK, features, group_rows, model_input, predict_frame, score_weeks, training_examples


MAX_STORE_WEEKS = 50_000


class ForecastRangeError(ValueError):
    """A forecast period the local item trainer cannot use."""


def parse_window(start, end):
    if start is None and end is None:
        return None
    if start is None or end is None:
        raise ForecastRangeError("Choose both a start week and an end week.")
    try:
        dates = [date.fromisoformat(value) for value in (start, end)]
        if any(day.isoformat() != value or day.weekday() != 0 for day, value in zip(dates, (start, end))):
            raise ValueError
    except (TypeError, ValueError):
        raise ForecastRangeError("Choose Mondays in YYYY-MM-DD format.") from None
    if dates[0] > dates[1]:
        raise ForecastRangeError("The end week must be on or after the start week.")
    return tuple(dates)


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
    """Issue one frozen-origin forecast across the requested weeks, including future dates."""
    if parameters is not None:
        validate_parameters(parameters)
    options = {**XGB_OPTIONS, **(parameters or {})}
    groups = group_rows(rows)
    if min(map(len, groups.values())) < 8:
        raise ValueError("Include at least eight consecutive weeks at each store.")
    stores = sorted(groups)
    start, end = period
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
        "forecastRange": {"start": start.isoformat(), "end": end.isoformat()},
        "training": {"initialRows": count, "finalRows": count, "holdoutWeeks": len(weeks),
                     "features": FEATURES, "storeOrder": list(history), "parameters": options,
                     "scope": "One fit on pre-period sales. Later weeks use the model's own predicted sales as lags."},
    }
    return result, model
