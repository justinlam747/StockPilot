import { useState } from 'react';
import parameterSpecs from '../../stockpilot_local/training_parameters.json';
import ForecastControls from './ForecastControls';
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

function scaleStep(points, models) {
  let max = 1;
  for (const row of points) {
    max = Math.max(max, row.actual ?? 0, ...models.map(({ id }) => row.forecasts[id] ?? 0));
  }
  const rough = max / 4;
  const magnitude = 10 ** Math.floor(Math.log10(rough));
  return [1, 2, 2.5, 5, 10].find(step => step * magnitude >= rough) * magnitude;
}

function ChartMarks({ points, selected, step, models }) {
  const n = points.length;
  const x = i => (100 * (i + 0.5) / n) + '%';
  const y = value => (100 * (1 - value / (4 * step))) + '%';
  return <svg className="fc-marks" aria-hidden="true" focusable="false">
    {points.map((p, i) => p.actual == null && <rect key={p.date} className="fc-future"
      x={100 * i / n + '%'} y="0" width={100 / n + '%'} height="100%" />)}
    {[0, 1, 2, 3, 4].map(i => <line key={i} className="fc-grid-line" x1="0" x2="100%" y1={i * 25 + '%'} y2={i * 25 + '%'} />)}
    <g className="fc-bars" data-series="actual">{points.map((p, i) => p.actual != null &&
      <rect key={p.date} x={(100 * (i + 0.27) / n) + '%'} y={y(p.actual)} width={(46 / n) + '%'}
        height={(100 * p.actual / (4 * step)) + '%'} />)}</g>
    <line className="fc-cursor" x1={x(selected)} x2={x(selected)} y1="0" y2="100%" />
    {models.map(model => <g key={model.id} className="fc-line" data-series={model.id} data-pattern={model.pattern}>
      {points.map((p, i) => p.forecasts[model.id] != null && points[i - 1]?.forecasts[model.id] != null &&
        <line key={p.date} x1={x(i - 1)} y1={y(points[i - 1].forecasts[model.id])} x2={x(i)} y2={y(p.forecasts[model.id])} />)}
      {points.map((p, i) => p.forecasts[model.id] != null && (model.pattern === 0 || i === selected || n === 1) &&
        <circle key={p.date} cx={x(i)} cy={y(p.forecasts[model.id])} r={i === selected ? 4.5 : 3} />)}
    </g>)}
  </svg>;
}

function WeekPlot({ points, dates, store, models, changeRange }) {
  const [inspected, setInspected] = useState(null);
  const [drag, setDrag] = useState(null);
  const step = scaleStep(points, models);
  const last = points.length - 1;
  const first = dates.indexOf(points[0].date);
  const clamp = index => Math.max(0, Math.min(last, index));
  const selected = inspected == null ? Math.max(0, points.findLastIndex(p => p.actual != null)) : clamp(inspected - first);
  const point = points[selected];
  const isFull = points.length === dates.length;

  function zoom(size) {
    const narrowing = size < points.length;
    const minStart = narrowing ? first : 0;
    const maxStart = narrowing ? first + points.length - size : dates.length - size;
    const start = Math.max(minStart, Math.min(maxStart, first + selected - Math.floor(size / 2)));
    setInspected(first + selected);
    changeRange(size === dates.length ? null : { start: dates[start], end: dates[start + size - 1] });
  }
  function weekAt(event) {
    const box = event.currentTarget.getBoundingClientRect();
    return clamp(Math.floor((event.clientX - box.left) / box.width * points.length));
  }
  function startDrag(event) {
    if (!event.isPrimary || event.button !== 0) return;
    const week = weekAt(event);
    setInspected(first + week);
    setDrag({ week, x: event.clientX, pointer: event.pointerId });
    event.currentTarget.setPointerCapture(event.pointerId);
  }
  function endDrag(event) {
    if (drag?.pointer !== event.pointerId) return;
    const week = weekAt(event);
    setDrag(null);
    setInspected(first + week);
    if (week === drag.week || Math.abs(event.clientX - drag.x) < 5) return;
    changeRange({ start: points[Math.min(week, drag.week)].date, end: points[Math.max(week, drag.week)].date });
  }
  function navigate(event) {
    const keys = { Home: 0, End: last, ArrowLeft: selected - 1, ArrowDown: selected - 1,
      ArrowRight: selected + 1, ArrowUp: selected + 1 };
    if (Object.hasOwn(keys, event.key)) { event.preventDefault(); setInspected(first + clamp(keys[event.key])); }
  }
  return <>
    <div className="fc-axis-title"><span>Units sold</span>
      <div className="fc-zoom" role="group" aria-label="Chart zoom">
        <button type="button" className="button" aria-label="Zoom out" title="Zoom out" disabled={isFull}
          onClick={() => zoom(Math.min(dates.length, points.length * 2))}>−</button>
        <button type="button" className="button" aria-label="Zoom in" title="Zoom in" disabled={last === 0}
          onClick={() => zoom(Math.ceil(points.length / 2))}>+</button>
        <button type="button" className="button" aria-label="Reset zoom" disabled={isFull}
          onClick={() => changeRange(null)}>Reset</button>
      </div>
    </div>
    <div className="fc-grid">
      <div className="fc-ticks" aria-hidden="true">{[4, 3, 2, 1, 0].map(i =>
        <span key={i}>{step * i >= 10000 ? compact.format(step * i) : units(step * i)}</span>)}</div>
      <div className="fc-plot" role="slider" tabIndex={0} aria-label={'Inspect weeks for ' + store}
        aria-valuemin={1} aria-valuemax={points.length} aria-valuenow={selected + 1}
        aria-valuetext={[dateLabel(point.date, true), 'Actual ' + units(point.actual),
          ...models.map(({ id, name }) => name + ' ' + units(point.forecasts[id]))].join(', ')}
        onKeyDown={navigate} onPointerDown={startDrag}
        onPointerMove={event => { if (event.isPrimary) setInspected(first + weekAt(event)); }}
        onPointerUp={endDrag} onLostPointerCapture={() => setDrag(null)} onPointerCancel={() => setDrag(null)}>
        <ChartMarks points={points} selected={selected} step={step} models={models} />
        {drag && selected !== drag.week && <div className="fc-zoom-selection" aria-hidden="true" style={{
          left: 100 * Math.min(selected, drag.week) / points.length + '%',
          width: 100 * (Math.abs(selected - drag.week) + 1) / points.length + '%',
        }} />}
      </div>
      <div className="fc-dates" aria-hidden="true">{points.map((p, i) =>
        <span key={p.date} data-mid={i === Math.floor(last / 2)}
          data-tick={i === 0 || i === last || i === Math.floor(last / 2) || i % Math.max(1, Math.ceil(points.length / 7)) === 0}>
          {dateLabel(p.date)}{p.isNext && <small>Next week</small>}</span>)}</div>
    </div>
    <div className="fc-readout"><time dateTime={point.date}>{dateLabel(point.date, true)}</time>
      <span>Actual <span data-value-for="actual" data-value={point.actual ?? ''}>{units(point.actual)}</span></span>
      {models.map(({ id, name }) => <span key={id}>{models.length === 1 && id === 'xgboost' ? 'Forecast' : name}{' '}
        <span data-value-for={id} data-value={point.forecasts[id] ?? ''}>{units(point.forecasts[id])}</span></span>)}
    </div>
  </>;
}

function Metric({ label, value, note, id, ...attrs }) {
  return <div className="fc-metric" data-kpi={id}>
    <dt>{label}</dt><dd className="fc-metric-number" {...attrs}>{units(value)}</dd><dd className="fc-note">{note}</dd>
  </div>;
}

function ChartLegend({ models, hidden, toggle }) {
  return <div className="fc-legend" aria-label="Chart series">
    <span><i className="fc-actual-key" />Actual sales</span>
    {models.map(({ id, name, pattern }) => {
      const mark = id === 'xgboost' ? <i className="fc-predicted-key" /> :
        <svg className="fc-line fc-peer-key" data-pattern={pattern} width="23" height="6" aria-hidden="true">
          <line x1="0" x2="23" y1="3" y2="3" />
        </svg>;
      if (models.length === 1) return <span key={id}>{mark}{name} forecast</span>;
      return <button type="button" key={id} aria-pressed={!hidden.includes(id)}
        onClick={() => toggle(id)}>{mark}{name}</button>;
    })}
  </div>;
}

function Indicators({ points, visible, store, hasNext }) {
  const next = points.at(-1), last = points.at(-2);
  const scored = visible.filter(p => p.available && Number.isFinite(p.actual) && Number.isFinite(p.forecasts.xgboost));
  const mae = scored.length ? scored.reduce((sum, p) => sum + Math.abs(p.forecasts.xgboost - p.actual), 0) / scored.length : null;
  const known = visible.filter(p => Number.isFinite(p.actual));
  const predicted = visible.every(p => Number.isFinite(p.forecasts.xgboost)) ?
    visible.reduce((sum, p) => sum + p.forecasts.xgboost, 0) : null;
  return <dl className="fc-metrics" aria-label={store.name + ' forecast indicators'}>
    {hasNext ? <><Metric id="next" label="Next week’s forecast" value={next.forecasts.xgboost}
      note={'Units · ' + dateLabel(next.date)} data-next-units={next.forecasts.xgboost ?? ''} />
      <Metric id="actual" label="Last week’s sales" value={last.actual} note={'Units · ' + dateLabel(last.date)} /></> :
      <><Metric id="period" label="Forecast sales" value={predicted} note={'XGBoost · ' + visible.length + (visible.length === 1 ? ' week' : ' weeks') + ' in view'} />
        <Metric id="actual" label="Observed sales" value={known.length ? known.reduce((sum, p) => sum + p.actual, 0) : null}
          note={known.length ? 'Units · ' + known.length + (known.length === 1 ? ' observed week' : ' observed weeks') : 'Awaiting actuals'} /></>}
    <Metric id="mae" label="Mean absolute error" value={mae} data-store-mae={mae ?? ''}
      note={scored.length ? 'Units · ' + scored.length + (scored.length === 1 ? ' scored week' : ' scored weeks') : 'No scored weeks'} />
  </dl>;
}

export default function Results({ result }) {
  const [storeId, setStoreId] = useState(result.stores[0].id);
  const [window, setWindow] = useState(null);
  const [hidden, setHidden] = useState([]);
  const store = result.stores.find(s => s.id === storeId) ?? result.stores[0];
  const weeks = result.next ? [...result.weeks, result.next] : result.weeks;
  const points = weeks.map(week => {
    const row = week.stores.find(s => s.id === store.id);
    return { date: week.week, actual: row?.actual ?? null, available: row?.available, forecasts: row?.forecasts ?? {},
      isNext: result.next?.week === week.week };
  });
  const dates = points.map(p => p.date);
  const range = window && dates.includes(window.start) && dates.includes(window.end) ? window :
    { start: dates[0], end: dates.at(-1) };
  const visible = points.filter(p => p.date >= range.start && p.date <= range.end);
  const models = result.models.map((model, index) => ({ ...model, pattern: index }));
  const shown = models.length === 1 ? models : models.filter(model => !hidden.includes(model.id));
  function toggle(id) {
    setHidden(current => current.includes(id) ? current.filter(key => key !== id) : [...current, id]);
  }
  return <article className="fc-result" id="single-item-results" data-single-store={store.id}>
    <section className="fc-panel" aria-labelledby="fc-heading">
      <div className="fc-heading"><h2 id="fc-heading">Weekly sales</h2>
        <StorePicker stores={result.stores} current={store.id} change={setStoreId} /></div>
      <ChartLegend models={models} hidden={hidden} toggle={toggle} />
      <WeekPlot key={store.id} points={visible} dates={dates} store={store.name} models={shown} changeRange={setWindow} />
      <ForecastControls result={result} dates={dates} range={range} changeRange={setWindow} points={visible} />
    </section>
    <Indicators points={points} visible={visible} store={store} hasNext={Boolean(result.next)} />
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
    <div className="fc-table" role="region" aria-label={result.forecastRange ? 'Weekly forecast observations' : 'Weekly backtest observations'} tabIndex={0}><table>
      <caption>{result.forecastRange ? 'Forecast by week' : 'Held-out weekly sales'}</caption>
      <thead><tr>{['Week', 'Store', 'Actual', ...result.models.map(model => model.name), 'Scored'].map(label => <th key={label} scope="col">{label}</th>)}</tr></thead>
      <tbody>{result.weeks.flatMap(week => week.stores.map(row => <tr key={week.week + '/' + row.id}>
        <td>{dateLabel(week.week, true)}</td><td>{names.get(row.id) ?? row.id}</td>
        <td>{units(row.actual)}</td>{result.models.map(model => <td key={model.id}>{units(row.forecasts[model.id])}</td>)}
        <td>{row.available && result.models.every(model => row.forecasts[model.id] != null) ? 'Yes' : 'No'}</td>
      </tr>))}</tbody></table></div>
    <p className="fc-note">{result.source.availability === 'assumed' ? 'Stock availability was omitted. Weeks are assumed to be in stock.'
      : 'Weeks marked out of stock are excluded from the error calculation.'}</p>
  </section>;
}
