'use client';

import { useState } from 'react';
import parameterSpecs from '../../stockpilot_local/training_parameters.json';
import { useWorkspace } from './Workspace';

const settings = Object.entries(parameterSpecs);

const columns = [
  ['week', 'Monday in YYYY-MM-DD format'],
  ['item', 'Item name or ID'],
  ['store', 'Store name or ID'],
  ['units_sold', 'Whole units sold, including zero'],
  ['in_stock', 'Optional. Use true or false.'],
];

function validParameter(value, spec) {
  const number = Number(value);
  return value.trim() !== '' && Number.isFinite(number) && number >= spec.min && number <= spec.max &&
    (!spec.integer || Number.isInteger(number));
}

function TrainingSettings({ values, setDraft, disabled, valid }) {
  const [expanded, setExpanded] = useState(!valid);
  return <div className="training-settings">
    <div className="settings-heading">
      <button type="button" className="settings-toggle" aria-expanded={expanded} aria-controls="training-controls"
        onClick={() => setExpanded(open => !open)}>Training settings</button>
      {!expanded && <span className="settings-summary">{valid
        ? `${values.n_estimators} ${Number(values.n_estimators) === 1 ? 'tree' : 'trees'} · depth ${values.max_depth} · rate ${values.learning_rate}`
        : 'Review the values to continue'}</span>}
    </div>
    <div id="training-controls" hidden={!expanded}>
      <div className="settings-fields">
        {settings.map(([key, spec]) => {
          const validField = validParameter(values[key], spec);
          return <div className="settings-field" key={key}>
            <label htmlFor={'param-' + key}>{spec.label}</label>
            <input type="number" id={'param-' + key} disabled={disabled} required min={spec.min} max={spec.max}
              step={spec.integer ? 1 : 'any'} value={values[key]} aria-invalid={!validField || undefined}
              aria-describedby={'range-' + key} onChange={event => {
                const value = event.currentTarget.value;
                setDraft(current => ({ ...current, [key]: value }));
              }} />
            <small id={'range-' + key}>{validField ? `${spec.min}–${spec.max}`
              : `Enter ${spec.integer ? 'a whole number' : 'a number'} from ${spec.min} to ${spec.max}.`}</small>
          </div>;
        })}
      </div>
      <button type="button" className="settings-toggle" disabled={disabled} onClick={() => setDraft({})}>Restore defaults</button>
    </div>
  </div>;
}

function UploadPanel() {
  const { pending, busy, loading, importSales, trainingDraft, setTrainingDraft } = useWorkspace();
  const values = Object.fromEntries(settings.map(([key, spec]) => [key, trainingDraft[key] ?? String(spec.default)]));
  const valid = settings.every(([key, spec]) => validParameter(values[key], spec));
  const disabled = busy || loading || !valid;
  function submit(file, item) {
    if (disabled) return;
    const parameters = Object.fromEntries(settings.map(([key]) => [key, Number(values[key])]));
    importSales(file, item, parameters);
  }
  return <section className="panel upload-area">
    <h2>Weekly sales CSV</h2>
    <p>Include eight or more consecutive weeks per store, ending on the same Monday.</p>
    <TrainingSettings values={values} valid={valid} setDraft={setTrainingDraft} disabled={busy} />
    <label className="button upload-button" aria-disabled={disabled}>
      Choose CSV file
      <input id="forecast-upload" type="file" accept=".csv,text/csv" disabled={disabled} onChange={event => {
        const file = event.currentTarget.files[0];
        event.currentTarget.value = '';
        if (file) submit(file);
      }} />
    </label>
    <small>Up to 1 MiB</small>
    {pending && <div className="item-choice">
      <label htmlFor="forecast-item">Choose an item from {pending.fileName}</label>
      <select id="forecast-item" value="" disabled={disabled} onChange={event => submit(null, event.target.value)}>
        <option disabled value="">Select item</option>
        {pending.items.map(item => <option key={item.id} value={item.id}>{item.name}</option>)}
      </select>
    </div>}
  </section>;
}

export default function ImportSales() {
  return <div className="page-body" id="import-page">
    <header className="page-head import-heading">
      <h1>Import sales</h1>
      <a href={process.env.NEXT_PUBLIC_SHOPIFY_CONNECT_URL || 'http://127.0.0.1:3001/connect'}>Connect Shopify</a>
    </header>
    <div className="import-layout">
      <UploadPanel />
      <section className="panel format-area">
        <h2>CSV format</h2>
        <div className="format">
          <dl>{columns.map(([name, description]) => <div key={name}>
            <dt>{name}</dt><dd>{description}</dd>
          </div>)}</dl>
          <a href="/weekly-sales-template.csv" download>Download CSV template</a>
        </div>
      </section>
    </div>
  </div>;
}
