// Settings page — dynamic model dropdown based on provider selection
var MODELS = {
  openai: [
    { value: 'gpt-4o', label: 'GPT-4o' },
    { value: 'gpt-4o-mini', label: 'GPT-4o Mini' },
    { value: 'o3-mini', label: 'o3-mini' }
  ],
  anthropic: [
    { value: 'claude-sonnet-4-20250514', label: 'Claude Sonnet 4' },
    { value: 'claude-haiku-4-5-20251001', label: 'Claude Haiku 4.5' }
  ],
  google: [
    { value: 'gemini-2.0-flash', label: 'Gemini 2.0 Flash' },
    { value: 'gemini-2.5-pro-preview-06-05', label: 'Gemini 2.5 Pro' }
  ]
};

function updateModelOptions() {
  var provider = document.getElementById('llm_provider');
  var model = document.getElementById('llm_model');
  if (!provider || !model) return;

  var selected = provider.value;
  var options = MODELS[selected] || [];
  var currentModel = model.getAttribute('data-current') || '';

  model.innerHTML = '';
  options.forEach(function (opt) {
    var el = document.createElement('option');
    el.value = opt.value;
    el.textContent = opt.label;
    if (opt.value === currentModel) el.selected = true;
    model.appendChild(el);
  });
}

document.addEventListener('DOMContentLoaded', function () {
  var model = document.getElementById('llm_model');
  if (model) {
    model.setAttribute('data-current', model.getAttribute('data-initial') || '');
    updateModelOptions();
  }
});
