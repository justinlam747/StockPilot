// Demo data toggle for bento dashboard
document.addEventListener("DOMContentLoaded", function () {
  var toggle = document.getElementById("demo-toggle");
  if (!toggle) return;

  var active = false;
  var realData = {};

  var dummyValues = ["1,247", "23", "5", "8", "3,891", "14"];

  var dummyAlerts = [
    { message: "Organic Cotton Tee (S) \u2014 3 units left", severity: "critical" },
    { message: "Recycled Denim Jacket (M) \u2014 7 units left", severity: "warning" },
    { message: "Merino Wool Beanie \u2014 5 units left", severity: "warning" }
  ];

  function saveReal() {
    realData.values = [];
    document.querySelectorAll(".bento__value").forEach(function (el) {
      realData.values.push(el.textContent);
    });
    var alertTile = document.querySelector(".bento__tile--alerts .bento__content");
    if (alertTile) realData.alertsHtml = alertTile.innerHTML;
    var agentStatus = document.getElementById("agent-status");
    if (agentStatus) realData.agentHtml = agentStatus.innerHTML;
    var badge = document.querySelector(".bento__badge");
    if (badge) realData.badge = badge.textContent;
  }

  function applyDummy() {
    var els = document.querySelectorAll(".bento__value");
    els.forEach(function (el, i) {
      if (dummyValues[i]) el.textContent = dummyValues[i];
    });

    var badge = document.querySelector(".bento__badge");
    if (badge) badge.textContent = "47";

    var alertTile = document.querySelector(".bento__tile--alerts .bento__content");
    if (alertTile) {
      var html = '<div class="bento__alert-list">';
      dummyAlerts.forEach(function (a) {
        html += '<div class="bento__alert-row bento__alert-row--' + a.severity + '"><span>' + a.message + '</span></div>';
      });
      html += '<span class="bento__meta">+ 44 more</span></div>';
      html += '<span class="bento__action">View all alerts &rarr;</span>';
      alertTile.innerHTML = html;
    }

    var agentStatus = document.getElementById("agent-status");
    if (agentStatus) {
      agentStatus.innerHTML = '<span class="bento__meta">Last run: Mar 19, 09:42 \u00b7 23 items flagged</span>';
    }
  }

  function restoreReal() {
    var els = document.querySelectorAll(".bento__value");
    els.forEach(function (el, i) {
      if (realData.values && realData.values[i]) el.textContent = realData.values[i];
    });
    var badge = document.querySelector(".bento__badge");
    if (badge && realData.badge) badge.textContent = realData.badge;
    var alertTile = document.querySelector(".bento__tile--alerts .bento__content");
    if (alertTile && realData.alertsHtml) alertTile.innerHTML = realData.alertsHtml;
    var agentStatus = document.getElementById("agent-status");
    if (agentStatus && realData.agentHtml) agentStatus.innerHTML = realData.agentHtml;
  }

  toggle.addEventListener("click", function () {
    active = !active;
    toggle.classList.toggle("is-active", active);
    if (active) {
      saveReal();
      applyDummy();
    } else {
      restoreReal();
    }
  });
});
