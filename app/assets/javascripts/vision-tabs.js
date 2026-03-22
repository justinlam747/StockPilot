// Vision page — tab switching via sidebar
document.addEventListener("DOMContentLoaded", function () {
  var links = document.querySelectorAll(".v-sidebar__link");
  var tabs = document.querySelectorAll(".v-tab");

  if (!links.length || !tabs.length) return;

  links.forEach(function (link) {
    link.addEventListener("click", function (e) {
      e.preventDefault();
      var tabId = link.getAttribute("data-tab");

      // Update sidebar active state
      links.forEach(function (l) { l.classList.remove("is-active"); });
      link.classList.add("is-active");

      // Show the matching tab, hide others
      tabs.forEach(function (tab) {
        if (tab.id === "tab-" + tabId) {
          tab.classList.add("is-active");
          // Scroll to top of content
          tab.scrollIntoView({ behavior: "smooth", block: "start" });
        } else {
          tab.classList.remove("is-active");
        }
      });
    });
  });
});
