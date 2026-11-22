"""Fixed-origin forecasts must never learn from a sale inside the displayed window."""

from datetime import date, timedelta

import pytest

from stockpilot_local.window import ForecastRangeError, parse_window, train_window
from stockpilot_local.xgb import predict_next


def sales(start_offsets=(0, 0)):
    return [
        dict(store=store, item="Cardigan", week=(date(2024, 1, 1) + timedelta(weeks=i)).isoformat(),
             units_sold=i + offset, in_stock=True)
        for store, offset in zip(("A", "B"), start_offsets, strict=True) for i in range(offset, 14)
    ]


def test_fixed_origin_uses_only_prior_rows_and_keeps_future_actuals_empty():
    rows = sales()
    period = parse_window("2024-03-18", "2024-04-15")
    result, model = train_window(rows[::-1], period)
    changes = [dict(row, units_sold=500) if row["week"] >= "2024-03-18" else row for row in rows]
    altered, _ = train_window(changes, period)
    predictions = lambda run: [cell["forecasts"] for w in run["weeks"] for cell in w["stores"]]
    assert predictions(altered) == predictions(result)
    assert result["scores"][0]["mae"] != altered["scores"][0]["mae"]
    assert result["scores"][0]["count"] == 6
    assert result["next"] is None
    assert result["training"]["finalRows"] == 20
    assert all(r["actual"] is None and r["available"] is None for w in result["weeks"][-2:] for r in w["stores"])
    first = predict_next(model, [r for r in rows if r["week"] < "2024-03-18"])
    assert first["week"] == result["weeks"][0]["week"]
    assert [r["forecasts"] for r in first["stores"]] == predictions(result)[:2]


def test_missing_store_history_and_gap_weeks():
    rows = sales((0, 6))
    early, _ = train_window(rows, parse_window("2024-02-05", "2024-02-19"))
    assert early["training"]["storeOrder"] == ["A"]
    assert early["scores"][2]["count"] == 0
    assert early["weeks"][-1]["stores"][1]["actual"] is not None
    assert early["weeks"][-1]["stores"][1]["forecasts"]["xgboost"] is None
    all_weeks, _ = train_window(rows, parse_window("2024-04-08", "2024-05-06"))
    after_gap, _ = train_window(rows, parse_window("2024-05-06", "2024-05-06"))
    assert after_gap["weeks"] == all_weeks["weeks"][-1:]
    assert after_gap["scores"][0]["mae"]["xgboost"] is None


def test_monday_bounds_and_resource_limit():
    assert parse_window(None, None) is None
    for start, end in (("2024-01-01", None), (False, 1), ("2024-01-02", "2024-01-08"),
                       ("2024-01-15", "2024-01-08")):
        with pytest.raises(ForecastRangeError):
            parse_window(start, end)
    with pytest.raises(ForecastRangeError, match="50,000"):
        train_window(sales(), parse_window("3999-11-29", "3999-11-29"))
    with pytest.raises(ForecastRangeError, match="training week"):
        train_window(sales(), parse_window("2024-01-01", "2024-01-08"))
