import json
from datetime import date, timedelta

import pytest
from xgboost import XGBRegressor

from stockpilot_local import store
from stockpilot_local.worker import parse_csv, process_request
from stockpilot_local.xgb import predict_next


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


@pytest.mark.parametrize("parameters,error", [
    (None, "object"), ([], "object"), ({"n_jobs": 2}, "Unknown"),
    ({"max_depth": True}, "Maximum depth"), ({"max_depth": 0}, "Maximum depth"),
    ({"max_depth": 7}, "Maximum depth"), ({"n_estimators": "40"}, "Trees"),
    ({"n_estimators": 2.5}, "Trees"), ({"n_estimators": 201}, "Trees"),
    ({"learning_rate": None}, "Learning rate"), ({"learning_rate": 0.005}, "Learning rate"),
    ({"learning_rate": 0.301}, "Learning rate"), ({"learning_rate": float("nan")}, "Learning rate"),
    ({"learning_rate": float("inf")}, "Learning rate"),
])
def test_invalid_parameters_rejected_before_selection_or_saving(parameters, error, tmp_path, monkeypatch):
    monkeypatch.setenv("STOCKPILOT_DATA_DIR", str(tmp_path))
    with pytest.raises(ValueError, match=error):
        process_request({"csv": dataset(), "parameters": parameters})
    assert list(tmp_path.iterdir()) == []


@pytest.mark.parametrize("header,records,error", [
    ("week,item,store,units_sold", "2025-01-06,A,B,-1", "nonnegative"),
    ("week,item,store,units_sold", "2025-01-06,A,B,", "nonnegative"),
    ("week,item,store,units_sold", "2025-01-07,A,B,2", "Monday"),
    ("week,item,store,units_sold", "2025-01-06,A,B,2\n2025-01-06,A,B,3", "repeats"),
    ("week,item,store,units", "2025-01-06,,B,2", "item and a store"),
    ("week,item,store,units,in_stock", "2025-01-06,A,B,2,", "in_stock"),
    ("week,item,store,units,units_sold", "2025-01-06,A,B,2,2", "unambiguous"),
    ("week,item,store,stock", "2025-01-06,A,B,2", "Missing CSV columns"),
    ("week,item,store,units", "2025-01-06,A,B,2,extra", "different number"),
])
def test_invalid_csv(header, records, error):
    with pytest.raises(ValueError, match=error):
        parse_csv(header + "\n" + records)


def test_csv_alias_bom_quotes_stock_and_missing_weeks():
    groups, reported = parse_csv('\ufeff week ,item,store,units,in_stock\r\n2025-01-06,"A,2",B,0,1\r\n2025-01-20,"A,2",B,3,false')
    assert reported and [r["in_stock"] for r in groups["A,2"]] == [True, False]
    assert [r["units_sold"] for r in groups["A,2"]] == [0, 3]


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
