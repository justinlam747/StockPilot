import { useState } from 'react';
import { useWorkspace } from './Workspace';
import './queue.css';

const labels = { queued: 'Queued', running: 'Running', completed: 'Completed', failed: 'Failed', skipped: 'Skipped' };
const timestamp = new Intl.DateTimeFormat(undefined, { month: 'short', day: 'numeric', hour: 'numeric', minute: '2-digit' });

function ModelStates({ models, names }) {
  return <ul className="queue-models" aria-label="Models">
    {models.map(model => <li key={model.id} data-model-status={model.status}>
      {names.get(model.id) ?? model.id.replaceAll('_', ' ')}
      {models.length > 1 && <span> · {labels[model.status]}</span>}
      {model.error && <span className="queue-error"> · {model.error}</span>}
    </li>)}
  </ul>;
}

function QueueRow({ job, names, openJob, viewing, busy }) {
  return <li className="queue-row" data-job-id={job.id} data-job-status={job.status}>
    <div className="queue-identity">
      <div className="queue-title"><span>{job.item}</span>
        <span className="queue-status" data-status={job.status}>{labels[job.status]}</span></div>
      <ModelStates models={job.models} names={names} />
      <div className="queue-meta"><time dateTime={job.createdAt}>{timestamp.format(new Date(job.createdAt))}</time>
        {job.forecastStart && <span>{job.forecastStart} – {job.forecastEnd}</span>}</div>
      {job.error && <p className="queue-error">{job.error}</p>}
    </div>
    {job.status === 'completed' && (viewing ? <span className="queue-viewing">Viewing</span> :
      <button className="button" type="button" disabled={busy} onClick={() => openJob(job.id)}
        aria-label={'Open forecast for ' + job.item + ', ' + timestamp.format(new Date(job.createdAt))}>Open</button>)}
  </li>;
}

export default function ForecastQueue() {
  const { jobs, queueError, view, peerModels, openJob, busy } = useWorkspace();
  const [limit, setLimit] = useState(4);
  const names = new Map([['xgboost', 'XGBoost'], ...[...(peerModels ?? []), ...(view.result?.models ?? [])]
    .map(({ id, name }) => [id, name])]);
  const active = jobs?.filter(job => job.status === 'running').length ?? 0;
  const queued = jobs?.filter(job => job.status === 'queued').length ?? 0;
  const summary = [active && active + ' running', queued && queued + ' queued'].filter(Boolean).join(' · ');
  return <section className="panel forecast-queue" id="forecast-queue" aria-labelledby="queue-heading" tabIndex={-1}>
    <div className="queue-heading"><h2 id="queue-heading">Forecast queue</h2>
      <span role="status">{summary}</span></div>
    {queueError && <p className="queue-error" role="status">{queueError}</p>}
    {jobs?.length ? <ol className="queue-list">{jobs.slice(0, limit).map(job =>
      <QueueRow key={job.id} job={job} names={names} openJob={openJob} busy={busy} viewing={view.jobId === job.id} />
    )}</ol> : !queueError && <p className="queue-empty">{jobs ? 'No forecasts queued.' : 'Loading queue…'}</p>}
    {jobs?.length > limit && <button className="settings-toggle" type="button"
      onClick={() => setLimit(value => value + 8)}>Show more runs ({jobs.length - limit})</button>}
  </section>;
}
