'use client';

import { useEffect, useRef, useState } from 'react';
import ImportSales, { CsvFormat, UploadButton } from './ImportSales';
import Results from './Results';

async function request(path, signal, options) {
  const response = await fetch(path, {cache: 'no-store', ...options, signal});
  let data;
  try { data = await response.json(); }
  catch { throw new Error('The local forecast service could not read this request. Please try again.'); }
  if (!response.ok) throw new Error(data.error || 'The forecast request failed. Please try again.');
  return data;
}

function useWorkspace() {
  const [view, setView] = useState({projects: [], result: null, projectId: null});
  const [pending, setPending] = useState(null);
  const [notice, setNotice] = useState({message: '', error: false});
  const active = useRef(null);
  function begin(message) {
    active.current?.abort();
    const controller = new AbortController();
    active.current = controller;
    setNotice({message, error: false});
    return controller.signal;
  }
  function fail(signal, error) {
    if (!signal.aborted) setNotice({message: error.message, error: true});
  }
  async function open(id = '') {
    const signal = begin('Opening workspace…');
    setPending(null);
    try {
      const data = await request('/api/forecast' + (id ? '?id=' + encodeURIComponent(id) : ''), signal);
      if (!signal.aborted) { setView(data); setNotice({message: '', error: false}); }
    } catch (error) { fail(signal, error); }
  }
  useEffect(() => {
    open();
    return () => active.current?.abort();
  }, []);
  async function importSales(file, item) {
    const signal = begin('Training XGBoost on weekly sales…');
    if (file) setPending(null);
    try {
      if (file && file.size > 1024 * 1024) throw new Error('Choose a CSV of 1 MiB or smaller.');
      const csv = file ? await file.text() : pending.csv;
      if (signal.aborted) return;
      const data = await request('/api/forecast', signal, {method: 'POST',
        headers: {'Content-Type': 'application/json'}, body: JSON.stringify({csv, item})});
      if (signal.aborted) return;
      if (data.selectionRequired) {
        setPending({csv, items: data.items, fileName: file.name});
      } else {
        setView(data);
        setPending(null);
      }
      setNotice({message: '', error: false});
    } catch (error) { fail(signal, error); }
  }
  return {view, pending, notice, open, importSales};
}

function SavedProjects({ projects, current, open }) {
  const versions = new Map();
  const counts = new Map();
  for (const project of [...projects].reverse()) {
    const number = (counts.get(project.item) ?? 0) + 1;
    counts.set(project.item, number);
    versions.set(project.id, number);
  }
  return <label className="project-picker">Saved project
    <select id="project-select" value={current} onChange={event => open(event.target.value)}>
      {projects.map(project => <option key={project.id} value={project.id} title={project.savedAt}>
        {project.item}{counts.get(project.item) > 1 ? ' · import ' + versions.get(project.id) : ''}
      </option>)}
    </select>
  </label>;
}

export default function Workspace() {
  const {view, pending, notice, open, importSales} = useWorkspace();
  return <main className="workspace" id="one-item-workbench">
    <header className="workspace-bar"><span className="wordmark">StockPilot</span>
      {view.projects.length > 0 ? <SavedProjects projects={view.projects} current={view.projectId} open={open}/>
        : <span className="local-label">Local workspace</span>}
    </header>
    {view.result ? <div className="project-head"><div><p className="section-label">Item forecast</p>
      <h1>{view.result.item}</h1></div><UploadButton onFile={importSales}>Import CSV</UploadButton>
    </div> : <ImportSales onFile={importSales} />}
    {pending && <div className="item-choice"><label htmlFor="forecast-item">Choose one item from <strong>{pending.fileName}</strong></label>
      <select id="forecast-item" value="" onChange={event => importSales(null, event.target.value)}>
        <option disabled value="">Select item</option>
        {pending.items.map(item => <option key={item.id} value={item.id}>{item.name}</option>)}
      </select></div>}
    {notice.message && <p className="notice" id={notice.error ? 'forecast-error' : 'forecast-status'}
      role={notice.error ? 'alert' : 'status'}>{notice.message}</p>}
    {view.result && <><Results key={view.projectId + ':' + view.savedAt} result={view.result} />
      <details className="format-details"><summary>CSV format &amp; template</summary><CsvFormat /></details></>}
  </main>;
}
