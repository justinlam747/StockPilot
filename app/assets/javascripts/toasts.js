// Toast notification system for StockPilot
// Types: success, error, info
// Usage: StockPilot.toast("Message", "success")
(function () {
  "use strict";

  var TOAST_DURATION = 4000;
  var ANIMATION_DURATION = 300;
  var container = null;

  function getContainer() {
    if (container && document.body.contains(container)) return container;

    container = document.createElement("div");
    container.className = "toast-stack";
    container.setAttribute("role", "status");
    container.setAttribute("aria-live", "polite");
    container.setAttribute("aria-atomic", "false");
    document.body.appendChild(container);
    return container;
  }

  function createToast(message, type) {
    type = type || "info";
    var toast = document.createElement("div");
    toast.className = "toast toast--" + type;
    toast.setAttribute("role", "alert");

    var icon = document.createElement("span");
    icon.className = "toast__icon";
    icon.setAttribute("aria-hidden", "true");
    if (type === "success") {
      icon.textContent = "\u2713";
    } else if (type === "error") {
      icon.textContent = "\u2717";
    } else {
      icon.textContent = "\u2139";
    }

    var text = document.createElement("span");
    text.className = "toast__text";
    text.textContent = message;

    var close = document.createElement("button");
    close.className = "toast__close";
    close.setAttribute("aria-label", "Dismiss notification");
    close.textContent = "\u00D7";
    close.addEventListener("click", function () {
      dismissToast(toast);
    });

    toast.appendChild(icon);
    toast.appendChild(text);
    toast.appendChild(close);

    return toast;
  }

  function dismissToast(toast) {
    toast.classList.add("toast--exiting");
    setTimeout(function () {
      if (toast.parentNode) {
        toast.parentNode.removeChild(toast);
      }
    }, ANIMATION_DURATION);
  }

  function showToast(message, type) {
    var stack = getContainer();
    var toast = createToast(message, type);
    stack.appendChild(toast);

    // Force reflow for animation
    toast.offsetHeight; // eslint-disable-line no-unused-expressions

    toast.classList.add("toast--visible");

    // Auto-dismiss
    var timer = setTimeout(function () {
      dismissToast(toast);
    }, TOAST_DURATION);

    // Pause on hover
    toast.addEventListener("mouseenter", function () {
      clearTimeout(timer);
    });

    toast.addEventListener("mouseleave", function () {
      timer = setTimeout(function () {
        dismissToast(toast);
      }, 2000);
    });
  }

  // Listen for HTMX agent-run-complete event (fired via HX-Trigger header)
  document.addEventListener("agent-run-complete", function () {
    showToast("Agent analysis complete", "success");
  });

  // Expose globally
  window.StockPilot = window.StockPilot || {};
  window.StockPilot.toast = showToast;
})();
