"""User-adjustable XGBoost settings shared with the local import form."""

import json
from pathlib import Path


FIELDS = json.loads(Path(__file__).with_name("training_parameters.json").read_text(encoding="utf-8"))
XGB_OPTIONS = {
    **{key: field["default"] for key, field in FIELDS.items()},
    "min_child_weight": 2, "reg_lambda": 1, "objective": "reg:squarederror",
    "tree_method": "hist", "random_state": 7, "n_jobs": 1,
}


def validate_parameters(parameters):
    if not isinstance(parameters, dict):
        raise ValueError("XGBoost parameters must be a JSON object.")
    for key, value in parameters.items():
        if key not in FIELDS:
            raise ValueError("Unknown XGBoost parameter. Choose trees, maximum depth or learning rate.")
        field = FIELDS[key]
        allowed_types = (int,) if field["integer"] else (int, float)
        if type(value) not in allowed_types or not field["min"] <= value <= field["max"]:
            unit = "a whole number" if field["integer"] else "a number"
            raise ValueError(f"{field['label']} must be {unit} from {field['min']} to {field['max']}.")
