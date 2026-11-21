import { useState } from 'react';

const amounts = new Intl.NumberFormat('en-US', { maximumFractionDigits: 2 });
const dates = new Intl.DateTimeFormat('en-US', { month: 'short', day: 'numeric', timeZone: 'UTC' });
const fullDates = new Intl.DateTimeFormat('en-US', { month: 'short', day: 'numeric', year: 'numeric', timeZone: 'UTC' });
const units = value => value == null ? '—' : amounts.format(value);
const dateLabel = (iso, full = false) => (full ? fullDates : dates).format(new Date(iso + 'T00:00:00Z'));

function WeekPlot({ points, selected, select, store, top }) {
  const size = points.length;
  const x = index => (index + 0.5) * 500 / size;
  const y = value => 112 - value / top * 104;
  const bound = index => Math.max(0, Math.min(index, size - 1));
  const width = Math.min(40, 290 / size);
  let path = '';
  points.forEach((point,i) => {
    if (point.forecast != null) path += (points[i-1]?.forecast != null ? ' L' : ' M') + x(i) + ' ' + y(point.forecast);
  });
  function inspect(event) {
    const box = event.currentTarget.getBoundingClientRect();
    select(bound(Math.floor((event.clientX - box.left) * size / box.width)));
  }
  function onKey(event) {
    const choices = {Home: 0, End: size-1, ArrowLeft: selected-1, ArrowRight: selected+1};
    if (Object.hasOwn(choices, event.key)) { event.preventDefault(); select(bound(choices[event.key])); }
  }
  return <div className="plot"><div className="plot-axis" aria-hidden="true"><span>{units(top)}</span><span>0</span></div>
    <div role="slider" tabIndex={0} aria-label={'Inspect weekly sales for ' + store} aria-valuemin={1} aria-valuemax={size}
      aria-valuenow={selected+1} aria-valuetext={dateLabel(points[selected].date, true) + ', actual ' + units(points[selected].actual) + ', forecast ' + units(points[selected].forecast)}
      onPointerDown={inspect} onPointerMove={inspect} onKeyDown={onKey}>
      <svg viewBox="0 0 500 120" preserveAspectRatio="none" aria-hidden="true">
        <rect className="future" x={500 - 500 / size} y="4" width={500 / size} height="108" />
        {[8,60,112].map(h => <line key={h} className="rule" x1="0" x2="500" y1={h} y2={h} />)}
        {points.map((p,i) => p.actual != null && <rect key={p.date} className="bar" x={x(i)-width/2} y={y(p.actual)}
          width={width} height={y(0)-y(p.actual)} />)}
        <path className="trend" data-series="xgboost" d={path} />
        {points.map((p,i) => p.forecast != null && <circle key={p.date} cx={x(i)} cy={y(p.forecast)} r={i === selected ? 3.5 : 2} />)}
        <line className="cursor" x1={x(selected)} x2={x(selected)} y1="4" y2="113" />
      </svg>
    </div>
    <div className="plot-dates" aria-hidden="true"><span>{dateLabel(points[0].date)}</span><span>Next · {dateLabel(points.at(-1).date)}</span></div>
  </div>;
}

function StoreCard({ store, points, score, top, selected, select }) {
  const point = points[selected], next = points.at(-1);
  return <section className="store-card" data-single-store={store.id} aria-label={store.name + ' forecast'}>
    <header className="store-header"><h3>{store.name}</h3>
      <div className="store-estimate"><strong data-next-units={next.forecast ?? ''}>{units(next.forecast)}</strong><span>units next week</span></div>
    </header>
    <WeekPlot points={points} selected={selected} select={select} store={store.name} top={top} />
    <div className="readout"><time dateTime={point.date}>{dateLabel(point.date)}</time>
      <span>Actual <b data-value-for="actual" data-value={point.actual ?? ''}>{units(point.actual)}</b></span>
      <span>XGBoost <b data-value-for="xgboost" data-value={point.forecast ?? ''}>{units(point.forecast)}</b></span>
    </div>
    <div className="store-error">Mean absolute error <strong data-store-mae={score?.mae.xgboost ?? ''}>{units(score?.mae.xgboost)} units</strong></div>
  </section>;
}

function Evaluation({ result, pooled }) {
  return <details id="training-details" className="evaluation"><summary>Training &amp; evaluation</summary>
    <div className="evaluation-metrics"><div><span>Initial training rows</span><b>{units(result.training.initialRows)}</b></div>
      <div><span>Final training rows</span><b>{units(result.training.finalRows)}</b></div>
      <div><span>Scored store-weeks</span><b>{units(pooled?.count)}</b></div>
      <div><span>Mean absolute error</span><b>{units(pooled?.mae.xgboost)} units</b></div></div>
    <p>XGBoost trains on this item's earlier sales across stores before forecasting each held-out week. Mean absolute error is the average distance between a forecast and observed sales.</p>
    <p>{result.source.availability === 'assumed' ? 'Stock availability was omitted. Reported sales during stockouts can understate demand.'
      : 'Weeks marked out of stock are excluded from the error calculation.'}</p>
    <div className="table-wrap" role="region" aria-label="Weekly backtest observations" tabIndex={0}><table>
      <caption>Held-out weekly sales</caption>
      <thead><tr><th>Week</th><th>Store</th><th>Actual</th><th>XGBoost</th><th>Scored</th></tr></thead>
      <tbody>{result.weeks.flatMap(week => week.stores.map(row => <tr key={week.week + '/' + row.id}>
        <td>{dateLabel(week.week, true)}</td><td>{result.stores.find(s => s.id === row.id)?.name ?? row.id}</td>
        <td>{units(row.actual)}</td><td>{units(row.forecasts.xgboost)}</td><td>{row.available && row.forecasts.xgboost != null ? 'Yes' : 'No'}</td>
      </tr>))}</tbody></table></div>
  </details>;
}

export default function Results({ result }) {
  const [selected, select] = useState(result.weeks.length - 1);
  const grouped = new Map(result.stores.map(store => [store.id, []]));
  let top = 1;
  for (const week of [...result.weeks, result.next]) for (const row of week.stores) {
    const forecast = row.forecasts.xgboost ?? null;
    grouped.get(row.id).push({date: week.week, actual: row.actual ?? null, forecast});
    top = Math.max(top, row.actual ?? 0, forecast ?? 0);
  }
  const pooled = result.scores.find(row => row.store == null);
  return <article id="single-item-results">
    <div className="forecast-header"><div><h2>Store forecasts</h2><p>Week of {dateLabel(result.next.week, true)}</p></div>
      <div className="legend"><span><i className="actual-key" />Actual sales</span><span><i className="forecast-key" />XGBoost</span></div>
    </div>
    <div className="stores">{result.stores.map(store => <StoreCard key={store.id} store={store} points={grouped.get(store.id)}
      selected={selected} select={select} top={Math.ceil(top)} score={result.scores.find(s => s.store === store.id)} />)}</div>
    <Evaluation result={result} pooled={pooled} />
  </article>;
}
