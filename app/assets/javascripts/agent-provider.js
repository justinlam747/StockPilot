// Wire provider dropdown to hidden form inputs
document.addEventListener("DOMContentLoaded", function () {
  var select = document.getElementById("agent-provider");
  var providerInput = document.getElementById("agent-provider-input");
  var modelInput = document.getElementById("agent-model-input");

  if (!select || !providerInput || !modelInput) return;

  select.addEventListener("change", function () {
    var val = select.value;
    if (val) {
      var parts = val.split("|");
      providerInput.value = parts[0] || "";
      modelInput.value = parts[1] || "";
    } else {
      providerInput.value = "";
      modelInput.value = "";
    }
  });
});
