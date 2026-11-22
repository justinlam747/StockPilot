import { useMemo, useState } from 'react';
import { useWorkspace } from './Workspace';
import { isActive } from './useForecastQueue';

function Timeline({ dates, range, change }) {
  const options = dates.map(date => <option key={date} value={date}>{date}</option>);
  return <div className="fc-dates-form" role="group" aria-label="Chart timeline">
    <h3>Chart window</h3>
    <label>From week<select value={range.start} onChange={event => {
      const start = event.target.value;
      change({ start, end: range.end < start ? start : range.end });
    }}>{options}</select></label>
    <label>Through week<select value={range.end} onChange={event => {
      const end = event.target.value;
      change({ start: range.start > end ? end : range.start, end });
    }}>{options}</select></label>
    <button className="settings-toggle" onClick={() => change(null)}>All weeks</button>
  </div>;
}

const WEEK_MS = 7 * 86400000;
const isoDate = stamp => new Date(stamp).toISOString().slice(0, 10);
const asMonday = date => {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(date ?? '')) return NaN;
  const stamp = Date.parse(date + 'T00:00:00Z');
  return Number.isFinite(stamp) && isoDate(stamp) === date && new Date(stamp).getUTCDay() === 1 ? stamp : NaN;
};

function forecastWeeks(history) {
  const first = asMonday(history?.start), last = asMonday(history?.end);
  const minimum = Math.max(4, history?.minTrainingWeeks ?? 4);
  // Earlier snapshots reserved only two weeks. Keep the current four-week floor on restore.
  const lower = Math.max(asMonday(history?.earliestStart), first + minimum * WEEK_MS);
  const weeks = [];
  for (let stamp = lower; stamp <= last; stamp += WEEK_MS) weeks.push(isoDate(stamp));
  return weeks;
}

function validPeriod(period, weeks) {
  return weeks.includes(period?.forecastStart) && weeks.includes(period?.forecastEnd) &&
    period.forecastStart <= period.forecastEnd;
}

function recommendedPeriod(history, weeks) {
  const recommended = { forecastStart: history?.recommendedStart, forecastEnd: history?.recommendedEnd };
  if (validPeriod(recommended, weeks)) return recommended;
  return { forecastStart: weeks[Math.max(0, weeks.length - 4)], forecastEnd: weeks.at(-1) };
}

function ForecastPeriod({ period, change, history, weeks, recommended }) {
  if (!weeks.length) return <p className="fc-note">No eligible forecast weeks in the imported sales history.</p>;
  const { forecastStart, forecastEnd } = period;
  const options = values => values.map(week => <option key={week} value={week}>{week}</option>);
  const weekCount = (asMonday(forecastEnd) - asMonday(forecastStart)) / WEEK_MS + 1;
  return <section role="group" aria-label="Forecast period">
    <div className="fc-dates-form">
      <h3>Historical forecast period</h3>
      <label>Forecast from<select value={forecastStart} onChange={event => {
        const start = event.target.value;
        change({ forecastStart: start, forecastEnd: start > forecastEnd ? start : forecastEnd });
      }}>{options(weeks)}</select></label>
      <label>Forecast through<select value={forecastEnd} onChange={event =>
        change({ forecastStart, forecastEnd: event.target.value })}>
        {options(weeks.filter(week => week >= forecastStart))}</select></label>
      <button className="settings-toggle" onClick={() => change(recommended)}>Use recommended dates</button>
    </div>
    {validPeriod(period, weeks) && <>
      <p className="fc-note">Training history · {history.start} to {isoDate(asMonday(forecastStart) - WEEK_MS)}</p>
      <p className="fc-note">Evaluation · {forecastStart} to {forecastEnd} · {weekCount} {weekCount === 1 ? 'week' : 'weeks'}</p>
    </>}
  </section>;
}

function Scores({ models, points }) {
  const matched = points.filter(row => row.available && Number.isFinite(row.actual) &&
    models.every(({ id }) => Number.isFinite(row.forecasts[id])));
  if (!matched.length) return <p className="fc-note">No scored weeks in this range.</p>;
  return <div className="fc-errors">
    <p>Mean absolute error · {matched.length} {matched.length === 1 ? 'week' : 'weeks'} in view</p>
    <dl>{models.map(({ id, name }) => {
      const error = matched.reduce((sum, row) => sum + Math.abs(row.forecasts[id] - row.actual), 0) / matched.length;
      return <div key={id}><dt>{name}</dt><dd>{error.toLocaleString('en-US', { maximumFractionDigits: 2 })} units</dd></div>;
    })}</dl>
  </div>;
}

export default function ForecastControls({ result, dates, range, changeRange, points, overlays, toggleOverlay }) {
  const { models, forecastRange, historyRange, modelWarnings } = result;
  const { peerModels, busy, rerunForecast, jobs } = useWorkspace();
  const activeCount = jobs?.filter(isActive).length ?? 0;
  const [panel, setPanel] = useState(null);
  const [peers, setPeers] = useState(() => models.filter(model => model.id !== 'xgboost').map(model => model.id));
  const weeks = useMemo(() => forecastWeeks(historyRange), [historyRange]);
  const recommended = recommendedPeriod(historyRange, weeks);
  const saved = { forecastStart: forecastRange?.start, forecastEnd: forecastRange?.end };
  const [selection, setSelection] = useState(null);
  const initialPeriod = validPeriod(saved, weeks) ? saved : recommended;
  const selectionKey = JSON.stringify([result.item, historyRange?.start, weeks[0], weeks.at(-1),
    initialPeriod.forecastStart, initialPeriod.forecastEnd]);
  const period = selection?.key === selectionKey ? selection.period : initialPeriod;
  const [error, setError] = useState('');
  const availablePeers = peers.filter(id => peerModels?.some(model => model.id === id && model.available !== false));
  const awaitingPeers = !peerModels && peers.length > 0;
  function togglePanel(name) {
    setPanel(current => current === name ? null : name);
  }
  function run() {
    if (!validPeriod(period, weeks)) {
      setError('Choose forecast weeks within the imported sales history.');
      setPanel('dates');
      return;
    }
    setError('');
    rerunForecast(availablePeers, period);
  }
  return <div className="fc-tools">
    <div className="fc-tools-row">
      <button className="button" aria-expanded={panel === 'dates'} aria-controls="forecast-date-controls"
        onClick={() => togglePanel('dates')}>Timeline</button>
      {(peerModels?.length > 0 || models.length > 1) && <button className="button" aria-expanded={panel === 'models'} aria-controls="forecast-model-controls"
        onClick={() => togglePanel('models')}>Compare models</button>}
      {activeCount > 0 && <a className="queue-link" href="#forecast-queue">View queue ({activeCount})</a>}
      <button className="button fc-rerun" disabled={busy || awaitingPeers || !weeks.length} onClick={run}>Queue forecast</button>
    </div>
    {panel === 'dates' && <div id="forecast-date-controls">
      <Timeline dates={dates} range={range} change={changeRange} />
      <ForecastPeriod history={historyRange} weeks={weeks} recommended={recommended} period={period}
        change={value => { setSelection({ key: selectionKey, period: value }); setError(''); }} />
    </div>}
    {panel === 'models' && <section id="forecast-model-controls" aria-label="Model comparison">
      {models.length > 1 && <fieldset><legend>Show on chart</legend>
        {models.map(model => <label key={model.id}><input type="checkbox"
          checked={overlays.includes(model.id)} onChange={() => toggleOverlay(model.id)} />{model.name}</label>)}
      </fieldset>}
      {peerModels?.length > 0 && <fieldset disabled={busy}><legend>Include in rerun</legend>
        {peerModels.map(model => <label key={model.id}><input type="checkbox" checked={availablePeers.includes(model.id)}
          disabled={model.available === false} onChange={event => setPeers(event.target.checked ?
            [...peers, model.id] : peers.filter(id => id !== model.id))} />
          {model.name}{model.available === false && ' (unavailable)'}</label>)}
      </fieldset>}
      {models.length > 1 && <Scores models={models} points={points} />}
    </section>}
    {error && <p className="fc-input-error" role="alert">{error}</p>}
    {modelWarnings?.map(({ id, name, message }) => <p className="fc-note" key={id} role="status">{name} · {message}</p>)}
  </div>;
}
