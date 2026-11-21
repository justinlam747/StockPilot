'use client';

import { EmptyState, useWorkspace } from '../Workspace';
import { Evaluation } from '../Results';

export default function Page() {
  const { view, loading } = useWorkspace();
  return <div className="page-body" id="evaluation-page">
    <header className="page-head"><h1>Evaluation</h1>{view.result && <p>{view.result.item}</p>}</header>
    {view.result ? <Evaluation result={view.result} /> : loading ? <p role="status">Opening evaluation…</p> :
      <EmptyState>Import weekly sales to evaluate a forecast.</EmptyState>}
  </div>;
}
