// Tier 3: Live Agent Stream — real-time SSE streaming of agent execution steps.
// Replaces the blocking HTMX approach with async POST + EventSource.
(function () {
  "use strict";

  var runBtn = document.getElementById("agent-run-btn");
  var statusEl = document.getElementById("agent-status");
  if (!runBtn || !statusEl) return;

  var eventSource = null;
  var stepIndex = 0;
  var isStreaming = false;

  // Only attach live stream if the button has the data-live-stream attribute
  if (!runBtn.hasAttribute("data-live-stream")) return;

  // Remove HTMX attributes to prevent double-firing
  runBtn.removeAttribute("hx-post");
  runBtn.removeAttribute("hx-target");
  runBtn.removeAttribute("hx-indicator");
  runBtn.removeAttribute("hx-include");

  runBtn.addEventListener("click", function (e) {
    e.preventDefault();
    if (isStreaming) return;

    isStreaming = true;
    runBtn.disabled = true;
    runBtn.textContent = "Analyzing\u2026";
    stepIndex = 0;

    statusEl.innerHTML =
      '<div class="agent-stream-live" id="agent-stream-container">' +
      '<div class="agent-analyzing__pulse">' +
      '<span class="agent-analyzing__dot" aria-hidden="true"></span>' +
      '<span class="agent-analyzing__text">Starting agent\u2026</span>' +
      '</div></div>';

    // Get provider/model from select
    var sel = document.getElementById("agent-provider");
    var parts = sel && sel.value ? sel.value.split("|") : ["", ""];
    var provider = parts[0] || "";
    var model = parts[1] || "";

    // POST to start async run
    var csrfMeta = document.querySelector('meta[name="csrf-token"]');
    var csrfToken = csrfMeta ? csrfMeta.content : "";

    fetch("/agents/run_async", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": csrfToken,
      },
      body: JSON.stringify({ provider: provider, model: model }),
    })
      .then(function (resp) {
        if (resp.status === 409) {
          throw new Error("Agent already running. Please wait for it to finish.");
        }
        if (!resp.ok) throw new Error("Failed to start agent");
        return resp.json();
      })
      .then(function (data) {
        connectStream(data.run_id);
      })
      .catch(function (err) {
        resetButton();
        showError(err.message);
      });
  });

  function connectStream(runId) {
    if (eventSource) eventSource.close();

    eventSource = new EventSource("/agents/stream/" + runId);

    eventSource.addEventListener("step", function (e) {
      var data = JSON.parse(e.data);
      appendStep(data, "step");
    });

    eventSource.addEventListener("tool_call", function (e) {
      var data = JSON.parse(e.data);
      appendStep(data, "tool");
    });

    eventSource.addEventListener("tool_result", function (e) {
      var data = JSON.parse(e.data);
      appendStep(data, "result");
    });

    eventSource.addEventListener("complete", function (e) {
      var data = JSON.parse(e.data);
      closeStream();
      renderComplete(data);
    });

    eventSource.addEventListener("error", function () {
      if (eventSource && eventSource.readyState === EventSource.CLOSED) {
        closeStream();
        showError("Connection lost. Refresh to see results.");
      }
    });
  }

  function appendStep(data, type) {
    var container = document.getElementById("agent-stream-container");
    if (!container) return;

    // Remove the initial pulse indicator on first real step
    var pulse = container.querySelector(".agent-analyzing__pulse");
    if (pulse) pulse.remove();

    stepIndex++;
    var entry = document.createElement("div");
    entry.className = "agent-log__entry agent-log__entry--reveal";
    if (type === "tool") entry.classList.add("agent-log__entry--tool");
    if (type === "result") entry.classList.add("agent-log__entry--result");

    var icon = stepIcon(type);
    entry.innerHTML =
      '<span class="agent-log__step">' + icon + "</span>" +
      '<span class="agent-log__text">' + escapeHtml(data.message || "") + "</span>";

    container.appendChild(entry);
    entry.scrollIntoView({ behavior: "smooth", block: "end" });
  }

  function stepIcon(type) {
    if (type === "tool") return "\u2699"; // gear
    if (type === "result") return "\u2190"; // left arrow
    return stepIndex.toString();
  }

  function renderComplete(data) {
    var container = document.getElementById("agent-stream-container");
    if (!container) return;

    var summary = document.createElement("div");
    summary.className = "agent-log__summary agent-log__entry--reveal";

    var turns = data.turns || 0;
    var provider = data.provider || "unknown";
    var logEntries = data.log || [];
    var lowStock = data.low_stock_count || 0;

    var html = '<div class="agent-log__summary-header">' +
      '<span class="agent-log__check">\u2713</span> Analysis Complete' +
      '</div>' +
      '<div class="agent-log__summary-meta">' +
      provider + " \u00b7 " + turns + " turn(s)" +
      (lowStock > 0 ? " \u00b7 " + lowStock + " low-stock items" : "") +
      "</div>";

    // Show final log entries if available
    if (logEntries.length > 0) {
      var lastEntry = logEntries[logEntries.length - 1];
      if (typeof lastEntry === "string" && lastEntry.indexOf("Summary:") !== -1) {
        html +=
          '<div class="agent-log__summary-text">' +
          escapeHtml(lastEntry.replace(/^\[.*?\]\s*Summary:\s*/, "")) +
          "</div>";
      }
    }

    summary.innerHTML = html;
    container.appendChild(summary);
  }

  function closeStream() {
    if (eventSource) {
      eventSource.close();
      eventSource = null;
    }
    resetButton();
  }

  function resetButton() {
    isStreaming = false;
    runBtn.disabled = false;
    runBtn.textContent = "Run Analysis";
  }

  function showError(msg) {
    var container = document.getElementById("agent-stream-container");
    if (container) {
      var pulse = container.querySelector(".agent-analyzing__pulse");
      if (pulse) pulse.remove();
    }

    var errEl = document.createElement("div");
    errEl.className = "agent-log__error";
    errEl.innerHTML =
      '<span class="agent-log__error-icon">\u26A0</span> ' + escapeHtml(msg);

    if (container) {
      container.appendChild(errEl);
    } else {
      statusEl.innerHTML = "";
      statusEl.appendChild(errEl);
    }
  }

  function escapeHtml(str) {
    var div = document.createElement("div");
    div.textContent = str;
    return div.innerHTML;
  }
})();
