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
