'use client';

import Link from 'next/link';
import { useWorkspace } from './Workspace';
import Results from './Results';

export default function Page() {
  const { view, loading } = useWorkspace();
  return <div className="page-body" id="forecast-page">
    <header className="page-head"><h1>{view.result?.item ?? 'Forecast'}</h1></header>
    {view.result ? <Results key={view.result.item} result={view.result} /> :
      <section className="empty-chart" id="forecast-empty" aria-label="Forecast chart" aria-busy={loading}>
        <div className="empty-grid" aria-hidden="true">{[0, 1, 2, 3, 4].map(i => <i key={i} />)}</div>
        <div className="empty-chart-action">{loading ? <p role="status">Opening forecast…</p> :
          <><p>Import sales to see your forecast</p><Link className="button" href="/import">Import sales</Link></>}
        </div>
      </section>}
  </div>;
}
