// Agent streaming typewriter effect for StockPilot
// After HTMX swaps in agent results, stagger-animate each log entry
(function () {
  "use strict";

  var ENTRY_DELAY = 150; // ms between each entry appearing
  var ANALYZING_CLASS = "agent-analyzing";

  function animateEntries(container) {
    var entries = container.querySelectorAll("[data-stream-index]");
    if (!entries.length) return;

    // Hide all entries initially
    for (var i = 0; i < entries.length; i++) {
      entries[i].classList.add("agent-log__entry--hidden");
    }

    // Stagger reveal
    for (var j = 0; j < entries.length; j++) {
      (function (entry, index) {
        setTimeout(function () {
          entry.classList.remove("agent-log__entry--hidden");
          entry.classList.add("agent-log__entry--reveal");
        }, index * ENTRY_DELAY);
      })(entries[j], j);
    }
  }

  function showAnalyzingState() {
    var btn = document.getElementById("agent-run-btn");
    var status = document.getElementById("agent-status");
    if (!btn || !status) return;

    btn.disabled = true;
    btn.classList.add(ANALYZING_CLASS);
    btn.setAttribute("data-original-text", btn.textContent);
    btn.textContent = "Analyzing\u2026";

    // Add pulsing indicator to status area
    var pulse = document.createElement("div");
    pulse.className = "agent-analyzing__pulse";
    pulse.id = "agent-analyzing-pulse";
    pulse.innerHTML =
      '<span class="agent-analyzing__dot" aria-hidden="true"></span>' +
      '<span class="agent-analyzing__text">Scanning inventory data\u2026</span>';
    status.insertBefore(pulse, status.firstChild);
  }

  function clearAnalyzingState() {
    var btn = document.getElementById("agent-run-btn");
    if (btn) {
      btn.disabled = false;
      btn.classList.remove(ANALYZING_CLASS);
      var original = btn.getAttribute("data-original-text");
      if (original) btn.textContent = original;
    }

    var pulse = document.getElementById("agent-analyzing-pulse");
    if (pulse && pulse.parentNode) {
      pulse.parentNode.removeChild(pulse);
    }
  }

  // Before HTMX sends the request: show analyzing state
  document.addEventListener("htmx:beforeRequest", function (evt) {
    if (evt.detail.elt && evt.detail.elt.id === "agent-run-btn") {
      showAnalyzingState();
    }
  });

  // After HTMX swaps in new content: animate entries
  document.addEventListener("htmx:afterSwap", function (evt) {
    if (evt.detail.target && evt.detail.target.id === "agent-status") {
      clearAnalyzingState();

      var streamContainer = evt.detail.target.querySelector(
        "[data-agent-stream-entries]"
      );
      if (streamContainer) {
        animateEntries(streamContainer);
      }
    }
  });

  // Handle request errors
  document.addEventListener("htmx:responseError", function (evt) {
    if (evt.detail.target && evt.detail.target.id === "agent-status") {
      clearAnalyzingState();
      if (window.StockPilot && window.StockPilot.toast) {
        window.StockPilot.toast("Agent analysis failed. Please try again.", "error");
      }
    }
  });
})();
