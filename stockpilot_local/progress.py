"""Optional per-model status messages for a queue worker's stderr pipe."""

import json
import sys
from contextlib import contextmanager


def emit(model, status, error=None):
    event = {"model": model, "status": status}
    if error:
        event["error"] = error
    print("STOCKPILOT_EVENT " + json.dumps(event), file=sys.stderr, flush=True)


@contextmanager
def model_step(model, report):
    if report:
        report(model, "running")
    try:
        yield
    except Exception as exc:
        if report:
            report(model, "failed", str(exc) if isinstance(exc, ValueError) else "The model could not finish.")
        raise
    if report:
        report(model, "completed")
