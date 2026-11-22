'use client';

import { EmptyState, useWorkspace } from '../Workspace';

const savedDate = new Intl.DateTimeFormat(undefined, { dateStyle: 'medium', timeStyle: 'short' });

function ProjectList({ projects, projectId, open, busy }) {
  const versions = new Map();
  const counts = new Map();
  for (const project of [...projects].reverse()) {
    const number = (counts.get(project.item) ?? 0) + 1;
    counts.set(project.item, number);
    versions.set(project.id, number);
  }
  return <ul className="panel project-list" aria-label="Saved forecasts">
    {projects.map(project => {
      const name = counts.get(project.item) > 1 ? project.item + ' · run ' + versions.get(project.id) : project.item;
      return <li className="project-row" key={project.id}>
        <div className="project-identity">
          <span>{name}</span>
          <time dateTime={project.savedAt}>{savedDate.format(new Date(project.savedAt))}</time>
        </div>
        <button type="button" className="button" data-project-id={project.id} disabled={busy}
          aria-label={'Open ' + name} onClick={() => open(project.id)}>{project.id === projectId ? 'View forecast' : 'Open forecast'}</button>
      </li>;
    })}
  </ul>;
}

export default function Page() {
  const { view, open, busy, loading } = useWorkspace();
  return <div className="page-body" id="projects-page">
    <header className="page-head"><h1>Saved projects</h1></header>
    {view.projects.length ? <ProjectList projects={view.projects} projectId={view.projectId} open={open} busy={busy} /> :
      loading ? <p role="status">Opening projects…</p> : <EmptyState>No saved projects yet.</EmptyState>}
  </div>;
}
