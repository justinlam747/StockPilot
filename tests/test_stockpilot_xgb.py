from datetime import date, timedelta
from statistics import fmean

import pytest
from xgboost import XGBRegressor

from stockpilot_local import xgb
from stockpilot_local.xgb import predict_next, train_item


def weekly_rows():
    start = date(2024, 1, 1)
    return [
        {"item": "Sample sweater", "week": (start + timedelta(weeks=i)).isoformat(), "store": store,
         "units_sold": (i * 3 + shift) % 11, "in_stock": i != 7 or store != "Store A"}
        for store, shift in (("Store A", 2), ("Store B", 8)) for i in range(10)
    ]


def test_walk_forward_scores_and_training_cutoff():
    rows = weekly_rows()
    result, _ = train_item(rows)
    assert result["training"]["initialRows"] == 8
    assert result["training"]["finalRows"] == 17
    assert result["training"]["holdoutWeeks"] == 5
    assert result["training"]["storeOrder"] == ["Store A", "Store B"]
    pooled, store_a, store_b = result["scores"]
    assert (pooled["count"], store_a["count"], store_b["count"]) == (9, 4, 5)
    assert pooled["excluded"] == store_a["excluded"] == 1
    errors = [abs(row["actual"] - row["forecasts"]["xgboost"])
              for w in result["weeks"] for row in w["stores"] if row["available"]]
    assert pooled["mae"]["xgboost"] == round(fmean(errors), 6)
    first = result["weeks"][0]
    for row in rows:
        if row["week"] >= first["week"]:
            row["units_sold"] += 100
    updated, _ = train_item(rows)
    for a, b in zip(first["stores"], updated["weeks"][0]["stores"], strict=True):
        assert a["forecasts"] == b["forecasts"] and a["actual"] != b["actual"]


def test_native_model_roundtrip_with_recent_history(tmp_path):
    rows = weekly_rows()
    result, tree = train_item(rows)
    path = tmp_path / "model.json"
    tree.save_model(path)
    loaded = XGBRegressor()
    loaded.load_model(path)
    # The snapshot carries the training store order and original observation start dates.
    recent = [r for r in rows if r["week"] >= "2024-02-19"][::-1]
    assert predict_next(loaded, recent) == result["next"]
    order = result["training"]["storeOrder"]
    assert predict_next(loaded, rows, order) == result["next"]
    with pytest.raises(ValueError, match="order"):
        predict_next(loaded, rows, order[::-1])
    with pytest.raises(ValueError, match="item"):
        predict_next(loaded, [{**r, "item": "Different item"} for r in rows])
    with pytest.raises(ValueError, match="last week"):
        predict_next(loaded, [r for r in rows if r["week"] < "2024-03-04"])
    extended = [*recent, *[{**r, "week": "2024-03-11"} for r in recent if r["week"] == "2024-03-04"]]
    next_forecast = predict_next(loaded, extended)
    assert next_forecast["week"] == "2024-03-18"
    assert all(c["actual"] is None and c["forecasts"]["xgboost"] >= 0 for c in next_forecast["stores"])


def test_custom_options_apply_to_every_fit_without_changing_defaults(monkeypatch, tmp_path):
    rows = weekly_rows()
    default_result, _ = train_item(rows)
    fits = []

    def record_fit(**options):
        fits.append(options)
        return XGBRegressor(**options)

    monkeypatch.setattr(xgb, "XGBRegressor", record_fit)
    choices = {"n_estimators": 3, "max_depth": 1, "learning_rate": 0.3}
    expected = {**default_result["training"]["parameters"], **choices}
    result, tree = train_item(rows, parameters=choices)
    assert fits == [expected] * (result["training"]["holdoutWeeks"] + 1)
    assert result["training"]["parameters"] == expected
    assert result["weeks"] != default_result["weeks"]
    assert result["next"] != default_result["next"]
    assert choices == {"n_estimators": 3, "max_depth": 1, "learning_rate": 0.3}
    result["training"]["parameters"]["max_depth"] = 6
    assert train_item(rows)[0] == default_result
    tree.save_model(tmp_path / "model.ubj")
    loaded = XGBRegressor()
    loaded.load_model(tmp_path / "model.ubj")
    assert loaded.get_booster().num_boosted_rounds() == 3
    assert predict_next(loaded, rows) == result["next"]


def test_missing_dates_and_insufficient_training_are_explicit():
    rows = weekly_rows()
    with pytest.raises(ValueError, match="Missing week"):
        train_item(rows[:3] + rows[4:])
    with pytest.raises(ValueError, match="in-stock"):
        train_item([{**r, "in_stock": False} for r in rows])
    with pytest.raises(ValueError, match="one item"):
        train_item([*rows, {**rows[0], "item": "Other item"}])
    result, _ = train_item([{**r, "units_sold": 0} for r in rows])
    assert result["scores"][0]["mae"]["xgboost"] == 0
