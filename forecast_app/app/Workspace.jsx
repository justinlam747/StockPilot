'use client';

import { createContext, useContext, useEffect, useRef, useState } from 'react';
import Link from 'next/link';
import { usePathname, useRouter } from 'next/navigation';
import useForecastQueue, { displayedJob, request } from './useForecastQueue';

const WorkspaceContext = createContext(null);
const pages = [
  ['/forecast', 'Forecast'],
  ['/evaluation', 'Evaluation'],
  ['/import', 'Import sales'],
  ['/projects', 'Saved projects'],
];
const emptyView = { projects: [], projectId: null, result: null };
const quiet = { message: '', error: false };

export function useWorkspace() {
  return useContext(WorkspaceContext);
}

function Sidebar({ pathname }) {
  const [visible, setVisible] = useState(true);
  const toggle = useRef(null);
  useEffect(() => { setVisible(false); }, [pathname]);
  function onKeyDown(event) {
    if (event.key === 'Escape' && visible) {
      setVisible(false);
      toggle.current?.focus();
    }
  }
  return <aside className="sidebar" onKeyDown={onKeyDown}>
    <Link href="/forecast" className="wordmark" onClick={() => setVisible(false)}>StockPilot</Link>
    <button ref={toggle} type="button" className="nav-toggle" aria-controls="workspace-navigation"
      aria-expanded={visible} onClick={() => setVisible(current => !current)}>Menu</button>
    <nav className="sidebar-nav" id="workspace-navigation" aria-label="Workspace" data-open={visible}>
      {pages.map(([href, name]) => {
        const current = href === pathname || (pathname === '/' && href === '/forecast');
        return <Link key={href} href={href} aria-current={current ? 'page' : undefined}
          onClick={() => setVisible(false)}>{name}</Link>;
      })}
    </nav>
  </aside>;
}

function useLocalProject() {
  const router = useRouter();
  const active = useRef(null);
  const [view, setView] = useState(emptyView);
  const [pending, setPending] = useState(null);
  const [trainingDraft, setTrainingDraft] = useState({});
  const [peerModels, setPeerModels] = useState(null);
  const [notice, setNotice] = useState(quiet);
  const [loading, setLoading] = useState(true);
  const queue = useForecastQueue((job, restored) => {
    if (job.status === 'completed') openJob(job.id, false, restored);
    else setNotice({ message: job.error || 'Forecast failed.', error: true, scope: '/forecast' });
  });

  function begin(message, scope) {
    active.current?.abort();
    active.current = new AbortController();
    setNotice({ message, scope, error: false });
    return active.current.signal;
  }
  function fail(signal, error, scope) {
    if (!signal.aborted) setNotice({ message: error.message, scope, error: true });
  }
  function showForecast(from) {
    if (window.location.pathname === from) router.push('/forecast');
  }
  function showJob(snapshot, id, resetChart = false) {
    setView(current => ({ ...snapshot, jobId: id, chartSelection: resetChart ? id : current.chartSelection }));
    displayedJob(id);
    setNotice(quiet);
  }
  async function openJob(id, explicit = true, resetChart = explicit) {
    if (explicit) queue.forget();
    const signal = begin('Opening forecast…', '/forecast');
    try {
      const { snapshot } = await request('/api/forecast?job=' + encodeURIComponent(id) + '&result=1&activate=1', signal);
      if (signal.aborted) return;
      showJob(snapshot, id, resetChart);
      if (explicit) requestAnimationFrame(() => document.querySelector('#forecast-heading')?.focus());
    } catch (error) {
      fail(signal, error, '/forecast');
    } finally {
      if (!signal.aborted) setLoading(false);
    }
  }
  async function open(id) {
    if (id) queue.forget();
    const scope = id ? '/projects' : undefined;
    const signal = begin(id ? 'Opening project…' : '', scope);
    try {
      const previous = !id && displayedJob();
      if (previous) {
        try {
          const { snapshot } = await request('/api/forecast?job=' + encodeURIComponent(previous) + '&result=1', signal);
          if (!signal.aborted && snapshot) { showJob(snapshot, previous); return; }
        } catch (error) { if (error.status !== 404) throw error; }
      }
      const data = await request('/api/forecast' + (id ? '?id=' + encodeURIComponent(id) : ''), signal);
      if (signal.aborted) return;
      setView(data);
      displayedJob(null);
      setNotice(quiet);
      if (id) showForecast(scope);
    } catch (error) {
      fail(signal, error, scope);
    } finally {
      if (!signal.aborted) setLoading(false);
    }
  }
  useEffect(() => {
    open();
    return () => active.current?.abort();
  }, []);
  useEffect(() => {
    const controller = new AbortController();
    request('/api/forecast?capabilities=1', controller.signal)
      .then(data => { if (!controller.signal.aborted) setPeerModels(data.peerModels ?? []); })
      .catch(() => { if (!controller.signal.aborted) setPeerModels([]); });
    return () => controller.abort();
  }, []);

  async function enqueue(payload, signal) {
    const data = await request('/api/forecast', signal, { method: 'POST',
      headers: { 'Content-Type': 'application/json', Prefer: 'respond-async' }, body: JSON.stringify(payload) });
    if (!signal.aborted && data.job) queue.accepted(data.job);
    return data;
  }
  async function rerunForecast(peers, period) {
    if (!view.projectId) return;
    queue.forget();
    const scope = window.location.pathname;
    const signal = begin('Queuing forecast…', scope);
    try {
      await enqueue({ projectId: view.projectId, peers, ...period }, signal);
      if (signal.aborted) return;
      setNotice({ message: 'Forecast queued.', scope, done: true, error: false });
    } catch (error) {
      fail(signal, error, scope);
    }
  }

  async function importSales(file, item, parameters) {
    queue.forget();
    const signal = begin('Queuing forecast…', '/import');
    if (file) setPending(null);
    try {
      if (file && file.size > 1024 * 1024) throw new Error('Choose a CSV of 1 MiB or smaller.');
      const csv = file ? await file.text() : pending.csv;
      if (signal.aborted) return;
      const data = await enqueue({ csv, item, parameters }, signal);
      if (signal.aborted) return;
      setNotice(quiet);
      if (data.selectionRequired) {
        setPending({ csv, items: data.items, fileName: file.name });
        return;
      }
      setPending(null);
      showForecast('/import');
    } catch (error) {
      fail(signal, error, '/import');
    } finally {
      if (!signal.aborted) setLoading(false);
    }
  }
  const busy = Boolean(notice.message && !notice.error && !notice.done);
  return { view, pending, notice, open, importSales, loading, busy, trainingDraft, setTrainingDraft, peerModels,
    rerunForecast, jobs: queue.jobs, queueError: queue.queueError, openJob };
}

export function EmptyState({ children }) {
  return <section className="empty-state"><p>{children}</p>
    <Link href="/import" className="button">Import sales</Link></section>;
}

export default function Workspace({ children }) {
  const state = useLocalProject();
  const pathname = usePathname();
  const { notice } = state;
  return <WorkspaceContext.Provider value={state}>
    <a className="skip-link" href="#one-item-workbench">Skip to content</a>
    <div className="app-shell"><Sidebar pathname={pathname}/>
      <main className="workspace" id="one-item-workbench" tabIndex={-1}>
        {notice.message && (!notice.scope || notice.scope === pathname) &&
          <p className={notice.done ? 'sr-status' : 'notice'} id={notice.error ? 'forecast-error' : 'forecast-status'}
            role={notice.error ? 'alert' : 'status'}>{notice.message}</p>}
        {children}
      </main>
    </div>
  </WorkspaceContext.Provider>;
}
