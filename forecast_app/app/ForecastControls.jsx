import { useState } from 'react';
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

function ForecastPeriod({ period, change, history }) {
  return <div className="fc-dates-form" role="group" aria-label="Forecast period">
    <h3>Forecast period</h3>
    <label>Forecast from<input type="date" value={period.forecastStart} min={history?.earliestStart}
      onChange={event => change({ ...period, forecastStart: event.target.value })} /></label>
    <label>Forecast through<input type="date" value={period.forecastEnd} min={period.forecastStart || history?.earliestStart}
      onChange={event => change({ ...period, forecastEnd: event.target.value })} /></label>
    {(period.forecastStart || period.forecastEnd) && <button className="settings-toggle"
      onClick={() => change({ forecastStart: '', forecastEnd: '' })}>Reset period</button>}
  </div>;
}

function periodError({ forecastStart: first, forecastEnd: last }, minimum) {
  if (!first && !last) return '';
  if (!first || !last) return 'Choose both forecast dates.';
  if ([first, last].some(date => new Date(date + 'T00:00:00Z').getUTCDay() !== 1)) return 'Choose Mondays for the forecast weeks.';
  if (last < first) return 'Choose an end week on or after the start week.';
  if (minimum && first < minimum) return 'The first forecast week with enough training history is ' + minimum + '.';
  return '';
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
  const [period, setPeriod] = useState(() => ({ forecastStart: forecastRange?.start ?? '', forecastEnd: forecastRange?.end ?? '' }));
  const [error, setError] = useState('');
  const availablePeers = peers.filter(id => peerModels?.some(model => model.id === id && model.available !== false));
  const awaitingPeers = !peerModels && peers.length > 0;
  function togglePanel(name) {
    setPanel(current => current === name ? null : name);
  }
  function run() {
    const message = periodError(period, historyRange?.earliestStart);
    setError(message);
    if (message) { setPanel('dates'); return; }
    rerunForecast(availablePeers, period.forecastStart ? period : {});
  }
  return <div className="fc-tools">
    <div className="fc-tools-row">
      <button className="button" aria-expanded={panel === 'dates'} aria-controls="forecast-date-controls"
        onClick={() => togglePanel('dates')}>Timeline</button>
      {(peerModels?.length > 0 || models.length > 1) && <button className="button" aria-expanded={panel === 'models'} aria-controls="forecast-model-controls"
        onClick={() => togglePanel('models')}>Compare models</button>}
      {activeCount > 0 && <a className="queue-link" href="#forecast-queue">View queue ({activeCount})</a>}
      <button className="button fc-rerun" disabled={busy || awaitingPeers} onClick={run}>Queue forecast</button>
    </div>
    {panel === 'dates' && <div id="forecast-date-controls">
      <Timeline dates={dates} range={range} change={changeRange} />
      <ForecastPeriod history={historyRange} period={period} change={value => { setPeriod(value); setError(''); }} />
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
