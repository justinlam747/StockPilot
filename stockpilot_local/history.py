"""Shared weekly sales validation and historical training and evaluation boundaries."""

from datetime import date, timedelta

from .parameters import ForecastRangeError


WEEK = timedelta(weeks=1)
MIN_TRAINING_WEEKS = 4
DEFAULT_HOLDOUT_WEEKS = 4
MAX_STORE_WEEKS = 50_000


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


def history_range(groups):
    if min(map(len, groups.values())) < 8:
        raise ForecastRangeError("Include at least eight consecutive weeks at each store.")
    first = {store: min(group) for store, group in groups.items()}
    end = max(next(iter(groups.values())))  # All stores share the last observed Monday.
    # The launch week supplies lagged sales. Only subsequent in-stock rows can be training targets.
    first_target = min((week for store, group in groups.items() for week, (_, available) in group.items()
                        if available and week > first[store]), default=None)
    earliest = None
    if first_target is not None:
        candidate = max(max(first.values()) + MIN_TRAINING_WEEKS * WEEK, first_target + WEEK)
        if candidate <= end:
            earliest = candidate
    recommended = max(earliest, end - (DEFAULT_HOLDOUT_WEEKS - 1) * WEEK) if earliest else None
    return {"start": min(first.values()).isoformat(), "end": end.isoformat(),
            "earliestStart": earliest.isoformat() if earliest else None,
            "recommendedStart": recommended.isoformat() if recommended else None,
            "recommendedEnd": end.isoformat() if recommended else None, "minTrainingWeeks": MIN_TRAINING_WEEKS}


def historical_period(bounds, period, store_count):
    if not bounds["earliestStart"]:
        raise ForecastRangeError("No historical holdout has an earlier in-stock training target. "
                                 "Include an in-stock week after a store's first record and before the evaluation.")
    last = date.fromisoformat(bounds["end"])
    if period is None:
        start, end = date.fromisoformat(bounds["recommendedStart"]), last
    else:
        start, end = period
    if any(not isinstance(week, date) or week.weekday() != 0 for week in (start, end)):
        raise ForecastRangeError("Choose Mondays for the evaluation weeks.")
    if end < start:
        raise ForecastRangeError("Choose an end week on or after the start week.")
    if start < date.fromisoformat(bounds["earliestStart"]):
        raise ForecastRangeError(f"Start on or after {bounds['earliestStart']} to keep at least four "
                                 "earlier weeks per store and an in-stock training target.")
    if end > last:
        raise ForecastRangeError(f"End on or before the last observed week, {last.isoformat()}.")
    if ((end - start) // WEEK + 1) * store_count > MAX_STORE_WEEKS:
        raise ForecastRangeError("Choose a shorter evaluation period (50,000 store-weeks per run).")
    return start, end
