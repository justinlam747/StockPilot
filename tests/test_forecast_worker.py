import json
from datetime import date, timedelta

import pytest
from xgboost import XGBRegressor

from stockpilot_local import store
from stockpilot_local.worker import parse_csv, process_request
from stockpilot_local.xgb import predict_next, train_item


def dataset():
    weeks = [(date(2025, 1, 6) + timedelta(weeks=i)).isoformat() for i in range(8)]
    rows = [f'{week},"../../Black, cardigan",Montréal,{i}' for i, week in enumerate(weeks)]
    return "week,item,store,units_sold\n" + "\n".join([*rows, "2025-01-06,Other,Toronto,10"])


def test_selected_history_and_native_model_restore(tmp_path, monkeypatch):
    root = tmp_path / "forecasts"
    monkeypatch.setenv("STOCKPILOT_DATA_DIR", str(root))
    assert process_request({"op": "read"}) == {"projects": [], "result": None, "projectId": None, "savedAt": None}
    csv = dataset()
    choices = process_request({"csv": csv})
    assert choices["selectionRequired"] and len(choices["items"]) == 2
    assert not root.exists()
    item = "../../Black, cardigan"
    snapshot = process_request({"csv": csv, "item": item})
    project_id = snapshot["projectId"]
    assert store.PROJECT_ID.fullmatch(project_id)
    assert snapshot["projects"] == [{"id": project_id, "item": item, "savedAt": snapshot["savedAt"]}]
    folder = root / project_id
    assert {p.name for p in folder.iterdir()} == {"history.csv", "project.json", "model.ubj", "forecast.json"}
    groups, reported = parse_csv((folder / "history.csv").read_text(encoding="utf-8"))
    assert set(groups) == {item} and not reported
    result = snapshot["result"]
    assert result["source"]["availability"] == "assumed"
    model = XGBRegressor()
    model.load_model(folder / "model.ubj")
    assert predict_next(model, groups[item]) == result["next"]
    assert process_request({"op": "read"})["result"] == result
    assert process_request({"csv": csv, "item": item})["projectId"] == project_id
    updated = process_request({"csv": csv.replace("Montréal,7", "Montréal,18"), "item": item})
    assert updated["projectId"] != project_id and len(updated["projects"]) == 2
    assert process_request({"op": "read"})["projectId"] == updated["projectId"]
    assert process_request({"op": "read", "id": project_id})["result"] == result
    assert process_request({"op": "read"})["projectId"] == project_id


def test_explicit_defaults_reuse_a_project_and_custom_settings_survive_restore(tmp_path, monkeypatch):
    monkeypatch.setenv("STOCKPILOT_DATA_DIR", str(tmp_path))
    upload = {"csv": dataset(), "item": "../../Black, cardigan"}
    original = process_request(upload)
    defaults = {"n_estimators": 40, "max_depth": 2, "learning_rate": 0.05}
    assert process_request({**upload, "parameters": defaults})["projectId"] == original["projectId"]
    changed = process_request({**upload, "parameters": {"max_depth": 1}})
    assert changed["projectId"] != original["projectId"]
    assert len(changed["projects"]) == 2
    restored = process_request({"op": "read", "id": changed["projectId"]})
    assert restored["result"]["training"]["parameters"] == {**original["result"]["training"]["parameters"], "max_depth": 1}
    assert process_request({**upload, "parameters": {}})["projectId"] == original["projectId"]


def test_saved_rerun_does_not_need_an_upload_and_keeps_the_training_settings(tmp_path, monkeypatch):
    monkeypatch.setenv("STOCKPILOT_DATA_DIR", str(tmp_path))
    trained = process_request({"csv": dataset(), "item": "../../Black, cardigan", "parameters": {"max_depth": 4}})
    rerun = {"op": "rerun", "projectId": trained["projectId"]}
    repeated = process_request(rerun)
    assert repeated["result"] == trained["result"] and repeated["projectId"] == trained["projectId"]
    bounds = {"start": "2025-01-06", "end": "2025-02-24", "earliestStart": "2025-01-20"}
    assert repeated["result"]["historyRange"] == bounds
    assert process_request({"op": "read", "id": trained["projectId"]})["result"] == repeated["result"]
    assert process_request({"op": "capabilities"}) == {"peerModels": []}
    with pytest.raises(ValueError, match="Only XGBoost"):
        process_request({**rerun, "peers": ["previous_week"]})
    with pytest.raises(ValueError, match="invalid"):
        process_request({"op": "rerun", "projectId": "../"})
    with pytest.raises(store.UnknownProject):
        process_request({"op": "rerun", "projectId": "9" * 64})


def test_saved_project_can_change_forecast_period_and_restore_both_snapshots(tmp_path, monkeypatch):
    monkeypatch.setenv("STOCKPILOT_DATA_DIR", str(tmp_path))
    trained = process_request({"csv": dataset(), "item": "../../Black, cardigan"})
    dated = process_request({"op": "rerun", "projectId": trained["projectId"],
                             "forecastStart": "2025-02-24", "forecastEnd": "2025-03-10"})
    assert dated["projectId"] != trained["projectId"]
    assert dated["result"]["next"] is None
    assert [frame["stores"][0]["actual"] for frame in dated["result"]["weeks"]] == [7, None, None]
    assert process_request({"op": "read"})["result"] == dated["result"]
    assert process_request({"op": "rerun", "projectId": dated["projectId"]})["result"] == trained["result"]


def test_invalid_and_interrupted_writes_do_not_publish_a_project(tmp_path, monkeypatch):
    monkeypatch.setenv("STOCKPILOT_DATA_DIR", str(tmp_path))
    with pytest.raises(ValueError, match="ID is invalid"):
        store.restore("../../malicious")
    with pytest.raises(store.UnknownProject):
        store.restore("a" * 64)
    class FailedModel:
        def save_model(self, path):
            path.write_bytes(b"interrupted")
            raise OSError("No space")

    with pytest.raises(OSError):
        store.save([], {"item": "Partial"}, FailedModel(), False)
    assert list(tmp_path.iterdir()) == []


def test_queue_preflight_and_explicit_activation(tmp_path, monkeypatch):
    monkeypatch.setenv("STOCKPILOT_DATA_DIR", str(tmp_path))
    csv = dataset()
    inspect = {"op": "inspect", "action": "train", "csv": csv}
    item = "../../Black, cardigan"
    assert process_request(inspect) == process_request({"csv": csv})
    assert process_request({**inspect, "item": item}) == {"item": item}
    assert not list(tmp_path.iterdir())
    first = process_request({"csv": csv, "item": item})
    background = process_request({"csv": csv.replace("Montréal,7", "Montréal,17"), "item": item, "activate": False})
    background_id = background["projectId"]
    assert process_request({"op": "inspect", "action": "rerun", "projectId": background_id}) == {"item": item}
    assert process_request({"op": "read"})["projectId"] == first["projectId"]
    assert len(process_request({"op": "activate", "id": background_id})["projects"]) == 2
    assert process_request({"op": "read"})["projectId"] == background_id


def test_progress_only_in_opted_in_runs_and_failure_has_no_completed_event(tmp_path, monkeypatch, capsys):
    monkeypatch.setenv("STOCKPILOT_DATA_DIR", str(tmp_path))
    upload = {"csv": dataset(), "item": "../../Black, cardigan"}
    baseline = process_request(upload)
    assert not capsys.readouterr().err
    assert process_request({**upload, "progress": True}) == baseline
    events = [json.loads(line.removeprefix("STOCKPILOT_EVENT ")) for line in capsys.readouterr().err.splitlines()]
    assert events == [{"model": "xgboost", "status": status} for status in ["running", "completed"]]
    with pytest.raises(ValueError, match="eight"):
        process_request({**upload, "item": "Other", "progress": True})
    events = [json.loads(line.removeprefix("STOCKPILOT_EVENT ")) for line in capsys.readouterr().err.splitlines()]
    assert [(e["model"], e["status"]) for e in events] == [("xgboost", "running"), ("xgboost", "failed")]
    assert "eight" in events[-1]["error"]


def weekly_rows():
    start = date(2024, 1, 1)
    return [
        {"item": "Sample sweater", "week": (start + timedelta(weeks=i)).isoformat(), "store": store,
         "units_sold": (i * 3 + shift) % 11, "in_stock": i != 7 or store != "Store A"}
        for store, shift in (("Store A", 2), ("Store B", 8)) for i in range(10)
    ]


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
