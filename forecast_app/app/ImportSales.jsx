'use client';

import { useWorkspace } from './Workspace';

const columns = [
  ['week', 'Monday in YYYY-MM-DD format'],
  ['item', 'Item name or ID'],
  ['store', 'Store name or ID'],
  ['units_sold', 'Whole units sold, including zero'],
  ['in_stock', 'Optional. Use true or false.'],
];

export default function ImportSales() {
  const { pending, busy, loading, importSales } = useWorkspace();
  return <div className="page-body" id="import-page">
    <header className="page-head"><h1>Import sales</h1></header>
    <div className="import-layout">
      <section className="panel upload-area">
        <h2>Weekly sales CSV</h2>
        <p>Include eight or more consecutive weeks per store, ending on the same Monday.</p>
        <label className="button upload-button" aria-disabled={busy || loading}>
          Choose CSV file
          <input id="forecast-upload" type="file" accept=".csv,text/csv" disabled={busy || loading} onChange={event => {
            const file = event.currentTarget.files[0];
            event.currentTarget.value = '';
            if (file) importSales(file);
          }} />
        </label>
        <small>Up to 1 MiB</small>
        {pending && <div className="item-choice">
          <label htmlFor="forecast-item">Choose an item from {pending.fileName}</label>
          <select id="forecast-item" value="" disabled={busy}
            onChange={event => importSales(null, event.target.value)}>
            <option disabled value="">Select item</option>
            {pending.items.map(item => <option key={item.id} value={item.id}>{item.name}</option>)}
          </select>
        </div>}
      </section>
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
