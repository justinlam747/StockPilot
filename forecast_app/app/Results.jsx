import { useState } from 'react';
import parameterSpecs from '../../stockpilot_local/training_parameters.json';
import './charts.css';

const numbers = new Intl.NumberFormat('en-US', { maximumFractionDigits: 2 });
const compact = new Intl.NumberFormat('en-US', { notation: 'compact', maximumFractionDigits: 1 });
const dates = new Intl.DateTimeFormat('en-US', { month: 'short', day: 'numeric', timeZone: 'UTC' });
const fullDates = new Intl.DateTimeFormat('en-US', { month: 'short', day: 'numeric', year: 'numeric', timeZone: 'UTC' });
const units = value => value == null ? '—' : numbers.format(value);
const dateLabel = (iso, full = false) => (full ? fullDates : dates).format(new Date(iso + 'T00:00:00Z'));

function StorePicker({ stores, current, change }) {
  if (stores.length === 1) return <span className="fc-store-name">{stores[0].name}</span>;
  if (stores.length > 3) return <label className="fc-picker-label">Store
    <select id="forecast-store" value={current} onChange={event => change(event.target.value)}>
      {stores.map(store => <option key={store.id} value={store.id}>{store.name}</option>)}
    </select></label>;
  return <div className="fc-switch" role="group" aria-label="Store">
    {stores.map(store => <button type="button" key={store.id} data-store-switch={store.id}
      aria-pressed={store.id === current} onClick={() => change(store.id)}>{store.name}</button>)}
  </div>;
}

function scaleStep(weeks) {
  let max = 1;
  for (const week of weeks) for (const row of week.stores) {
    max = Math.max(max, row.actual ?? 0, row.forecasts.xgboost ?? 0);
  }
  const rough = max / 4;
  const magnitude = 10 ** Math.floor(Math.log10(rough));
  return [1, 2, 2.5, 5, 10].find(step => step * magnitude >= rough) * magnitude;
}

function ChartMarks({ points, selected, step }) {
  const n = points.length;
  const x = i => (100 * (i + 0.5) / n) + '%';
  const y = value => (100 * (1 - value / (4 * step))) + '%';
  return <svg className="fc-marks" aria-hidden="true" focusable="false">
    <rect className="fc-future" x={(100 - 100 / n) + '%'} y="0" width={(100 / n) + '%'} height="100%" />
    {[0, 1, 2, 3, 4].map(i => <line key={i} className="fc-grid-line" x1="0" x2="100%" y1={i * 25 + '%'} y2={i * 25 + '%'} />)}
    <g className="fc-bars" data-series="actual">{points.map((p, i) => p.actual != null &&
      <rect key={p.date} x={(100 * (i + 0.27) / n) + '%'} y={y(p.actual)} width={(46 / n) + '%'}
        height={(100 * p.actual / (4 * step)) + '%'} />)}</g>
    <line className="fc-cursor" x1={x(selected)} x2={x(selected)} y1="0" y2="100%" />
    <g className="fc-line" data-series="xgboost">
      {points.map((p, i) => p.forecast != null && points[i - 1]?.forecast != null &&
        <line key={p.date} x1={x(i - 1)} y1={y(points[i - 1].forecast)} x2={x(i)} y2={y(p.forecast)} />)}
      {points.map((p, i) => p.forecast != null &&
        <circle key={p.date} cx={x(i)} cy={y(p.forecast)} r={i === selected ? 4.5 : 3} />)}
    </g>
  </svg>;
}

function WeekPlot({ points, store, step }) {
  const [selected, select] = useState(points.length - 2);
  const last = points.length - 1;
  const point = points[selected];
  const clamp = index => Math.max(0, Math.min(last, index));
  function inspect(event) {
    const box = event.currentTarget.getBoundingClientRect();
    select(clamp(Math.floor((event.clientX - box.left) / box.width * points.length)));
  }
  function navigate(event) {
    const keys = { Home: 0, End: last, ArrowLeft: selected - 1, ArrowDown: selected - 1,
      ArrowRight: selected + 1, ArrowUp: selected + 1 };
    if (Object.hasOwn(keys, event.key)) { event.preventDefault(); select(clamp(keys[event.key])); }
  }
  return <>
    <div className="fc-axis-title">Units sold</div>
    <div className="fc-grid">
      <div className="fc-ticks" aria-hidden="true">{[4, 3, 2, 1, 0].map(i =>
        <span key={i}>{step * i >= 10000 ? compact.format(step * i) : units(step * i)}</span>)}</div>
      <div className="fc-plot" role="slider" tabIndex={0} aria-label={'Inspect weeks for ' + store}
        aria-valuemin={1} aria-valuemax={points.length} aria-valuenow={selected + 1}
        aria-valuetext={dateLabel(point.date, true) + ', actual ' + (point.actual == null ? 'unavailable' : units(point.actual)) + ', forecast ' + units(point.forecast)}
        onKeyDown={navigate} onPointerDown={inspect} onPointerMove={inspect}>
        <ChartMarks points={points} selected={selected} step={step} />
      </div>
      <div className="fc-dates" aria-hidden="true">{points.map((p, i) =>
        <span key={p.date} data-mid={i === Math.floor(last / 2)}>{dateLabel(p.date)}{i === last && <small>Next week</small>}</span>)}</div>
    </div>
    <div className="fc-readout"><time dateTime={point.date}>{dateLabel(point.date, true)}</time>
      <span>Actual <span data-value-for="actual" data-value={point.actual ?? ''}>{units(point.actual)}</span></span>
      <span>Forecast <span data-value-for="xgboost" data-value={point.forecast ?? ''}>{units(point.forecast)}</span></span>
    </div>
  </>;
}

function Metric({ label, value, note, id, ...attrs }) {
  return <div className="fc-metric" data-kpi={id}>
    <dt>{label}</dt><dd className="fc-metric-number" {...attrs}>{units(value)}</dd><dd className="fc-note">{note}</dd>
  </div>;
}

export default function Results({ result }) {
  const [storeId, setStoreId] = useState(result.stores[0].id);
  const store = result.stores.find(s => s.id === storeId) ?? result.stores[0];
  const weeks = [...result.weeks, result.next];
  const points = weeks.map(week => {
    const row = week.stores.find(s => s.id === store.id);
    return {date: week.week, actual: row?.actual ?? null, forecast: row?.forecasts.xgboost ?? null};
  });
  const next = points.at(-1), last = points.at(-2);
  const score = result.scores.find(s => s.store === store.id);
  const mae = score?.mae.xgboost;
  return <article className="fc-result" id="single-item-results" data-single-store={store.id}>
    <section className="fc-panel" aria-labelledby="fc-heading">
      <div className="fc-heading"><h2 id="fc-heading">Weekly sales</h2>
        <StorePicker stores={result.stores} current={store.id} change={setStoreId} /></div>
      <div className="fc-legend"><span><i className="fc-actual-key" />Actual sales</span>
        <span><i className="fc-predicted-key" />XGBoost forecast</span></div>
      <WeekPlot points={points} store={store.name} step={scaleStep(weeks)} />
    </section>
    <dl className="fc-metrics" aria-label={store.name + ' forecast indicators'}>
      <Metric id="next" label="Next week’s forecast" value={next.forecast} note={'Units · ' + dateLabel(next.date)}
        data-next-units={next.forecast ?? ''} />
      <Metric id="actual" label="Last week’s sales" value={last.actual} note={'Units · ' + dateLabel(last.date)} />
      <Metric id="mae" label="Mean absolute error" value={mae} data-store-mae={mae ?? ''}
        note={score?.count ? 'Units · ' + score.count + (score.count === 1 ? ' scored week' : ' scored weeks') : 'No scored weeks'} />
    </dl>
  </article>;
}

export function Evaluation({ result }) {
  const pooled = result.scores.find(score => score.store == null);
  const metrics = [['Initial training rows', result.training.initialRows], ['Final training rows', result.training.finalRows],
    ['Scored store-weeks', pooled?.count], ['Mean absolute error', pooled?.mae.xgboost]];
  const names = new Map(result.stores.map(store => [store.id, store.name]));
  return <section id="training-details" className="fc-evaluation" aria-label="Training and evaluation">
    <dl className="fc-evaluation-summary">{metrics.map(([label, value]) =>
      <div key={label}><dt>{label}</dt><dd>{units(value)}{label === 'Mean absolute error' && value != null && ' units'}</dd></div>)}</dl>
    <section className="fc-training" aria-labelledby="fc-training-heading">
      <h2 id="fc-training-heading">Training settings</h2>
      <dl>{Object.entries(parameterSpecs).map(([key, spec]) =>
        <div key={key}><dt>{spec.label}</dt><dd>{result.training.parameters?.[key] ?? 'Unrecorded'}</dd></div>)}</dl>
    </section>
    <div className="fc-table" role="region" aria-label="Weekly backtest observations" tabIndex={0}><table>
      <caption>Held-out weekly sales</caption>
      <thead><tr>{['Week', 'Store', 'Actual', 'XGBoost', 'Scored'].map(label => <th key={label} scope="col">{label}</th>)}</tr></thead>
      <tbody>{result.weeks.flatMap(week => week.stores.map(row => <tr key={week.week + '/' + row.id}>
        <td>{dateLabel(week.week, true)}</td><td>{names.get(row.id) ?? row.id}</td>
        <td>{units(row.actual)}</td><td>{units(row.forecasts.xgboost)}</td>
        <td>{row.available && row.forecasts.xgboost != null ? 'Yes' : 'No'}</td>
      </tr>))}</tbody></table></div>
    <p className="fc-note">{result.source.availability === 'assumed' ? 'Stock availability was omitted. Weeks are assumed to be in stock.'
      : 'Weeks marked out of stock are excluded from the error calculation.'}</p>
  </section>;
}
