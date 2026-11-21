const columns = [
  ['week', 'Monday in YYYY-MM-DD format'],
  ['item', 'Item name or stable item ID'],
  ['store', 'Store name or stable store ID'],
  ['units_sold', 'Whole units sold that week, including zero'],
];

export function UploadButton({ onFile, children }) {
  return <label className="upload-button">
    <input id="forecast-upload" type="file" accept=".csv,text/csv" onChange={event => {
      const file = event.currentTarget.files[0];
      event.currentTarget.value = '';
      if (file) onFile(file);
    }} />
    <span aria-hidden="true">↑</span>{children}
  </label>;
}

export function CsvFormat() {
  return <div className="format">
    <dl>{columns.map(([key, description]) => <div key={key}>
      <dt><code>{key}</code></dt><dd>{description}</dd>
    </div>)}</dl>
    <p>Optional <code>in_stock</code> accepts <code>true</code> or <code>false</code>.</p>
    <a href="/weekly-sales-template.csv" download>Download CSV template <span aria-hidden="true">↓</span></a>
  </div>;
}

export default function ImportSales({ onFile }) {
  return <section className="setup" aria-labelledby="setup-title">
    <div className="setup-intro"><h1 id="setup-title">Forecast one item</h1>
      <p>Train XGBoost on your weekly sales and forecast next week for each store.</p>
    </div>
    <div className="setup-grid">
      <section className="upload-area">
        <h2>Import sales history</h2>
        <p>Use one row per item, store and week. Include at least eight consecutive weeks per store, ending on the same Monday.</p>
        <UploadButton onFile={onFile}>Choose CSV file</UploadButton>
        <small>CSV · up to 1 MiB</small>
      </section>
      <section className="format-area"><h2>CSV format</h2><CsvFormat /></section>
    </div>
  </section>;
}
