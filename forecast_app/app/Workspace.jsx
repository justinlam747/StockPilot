'use client';

import { createContext, useContext, useEffect, useRef, useState } from 'react';
import Link from 'next/link';
import { usePathname, useRouter } from 'next/navigation';

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

async function request(path, signal, options) {
  const response = await fetch(path, { cache: 'no-store', ...options, signal });
  let data;
  try {
    data = await response.json();
  } catch {
    throw new Error('The local forecast service could not read this request. Please try again.');
  }
  if (!response.ok) throw new Error(data.error || 'The forecast request failed. Please try again.');
  return data;
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
  const [notice, setNotice] = useState(quiet);
  const [loading, setLoading] = useState(true);

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
  async function open(id) {
    const scope = id ? '/projects' : undefined;
    const signal = begin(id ? 'Opening project…' : '', scope);
    try {
      const data = await request('/api/forecast' + (id ? '?id=' + encodeURIComponent(id) : ''), signal);
      if (signal.aborted) return;
      setView(data);
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

  async function importSales(file, item) {
    const signal = begin('Training XGBoost…', '/import');
    if (file) setPending(null);
    try {
      if (file && file.size > 1024 * 1024) throw new Error('Choose a CSV of 1 MiB or smaller.');
      const csv = file ? await file.text() : pending.csv;
      if (signal.aborted) return;
      const data = await request('/api/forecast', signal, { method: 'POST',
        headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ csv, item }) });
      if (signal.aborted) return;
      setNotice(quiet);
      if (data.selectionRequired) {
        setPending({ csv, items: data.items, fileName: file.name });
        return;
      }
      setView(data);
      setPending(null);
      showForecast('/import');
    } catch (error) {
      fail(signal, error, '/import');
    } finally {
      if (!signal.aborted) setLoading(false);
    }
  }
  const busy = Boolean(notice.message && !notice.error);
  return { view, pending, notice, open, importSales, loading, busy };
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
          <p className="notice" id={notice.error ? 'forecast-error' : 'forecast-status'}
            role={notice.error ? 'alert' : 'status'}>{notice.message}</p>}
        {children}
      </main>
    </div>
  </WorkspaceContext.Provider>;
}
