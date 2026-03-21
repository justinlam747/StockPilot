// Sidebar — hover-to-expand (desktop) + drawer (mobile)
document.addEventListener("DOMContentLoaded", function () {
  var sidebar = document.getElementById("sidebar");
  var desktop = document.getElementById("sidebar-desktop");
  var drawer = document.getElementById("sidebar-drawer");
  var overlay = document.getElementById("sidebar-overlay");
  var openBtn = document.getElementById("sidebar-mobile-open");
  var closeBtn = document.getElementById("sidebar-mobile-close");

  if (!sidebar || !desktop) return;

  // Desktop: expand on hover
  desktop.addEventListener("mouseenter", function () {
    sidebar.setAttribute("data-expanded", "true");
  });

  desktop.addEventListener("mouseleave", function () {
    sidebar.setAttribute("data-expanded", "false");
  });

  // Mobile: open drawer
  if (openBtn) {
    openBtn.addEventListener("click", function () {
      drawer.classList.add("is-open");
      overlay.classList.add("is-visible");
      drawer.setAttribute("aria-hidden", "false");
      openBtn.setAttribute("aria-expanded", "true");
    });
  }

  function closeDrawer() {
    drawer.classList.remove("is-open");
    overlay.classList.remove("is-visible");
    drawer.setAttribute("aria-hidden", "true");
    if (openBtn) openBtn.setAttribute("aria-expanded", "false");
  }

  if (closeBtn) closeBtn.addEventListener("click", closeDrawer);
  if (overlay) overlay.addEventListener("click", closeDrawer);

  // Close on Escape
  document.addEventListener("keydown", function (e) {
    if (e.key === "Escape" && drawer.classList.contains("is-open")) {
      closeDrawer();
    }
  });
});
