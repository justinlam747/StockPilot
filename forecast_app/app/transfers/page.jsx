'use client';

import { useEffect, useRef, useState } from 'react';
import { useWorkspace } from '../Workspace';
import StoreMap from './StoreMap';
import { CELLS, coordinate, createBoard, dispatch, elapsedAt, placeStore, playback, readBoard, snapshot, TRAVEL_MS } from './simulation.mjs';
import './transfers.css';

function useBoard(key, item, names) {
  const [board, setBoard] = useState(null);
  const current = useRef(null);
  const seed = useRef({ item, names });
  const temporary = useRef(false);
  const [now, setNow] = useState(0);
  const [error, setError] = useState('');
  const [saved, setSaved] = useState(true);
  function remember(next, at) {
    current.current = next;
    setNow(at);
    setBoard(next);
  }
  function read() {
    if (temporary.current) return null;
    try { return readBoard(localStorage, key); }
    catch { temporary.current = true; setSaved(false); return null; }
  }
  function write(value) {
    if (temporary.current) return;
    try { localStorage.setItem(key, JSON.stringify(value)); setSaved(true); }
    catch { temporary.current = true; setSaved(false); }
  }
  useEffect(() => {
    function load() {
      const at = Date.now();
      const existing = read();
      const value = existing ?? createBoard(seed.current.item, seed.current.names, at);
      if (!existing) write(value);
      remember(value, at);
    }
    function sync(event) { if (!temporary.current && (event.key === key || event.key === null)) load(); }
    load();
    window.addEventListener('storage', sync);
    return () => window.removeEventListener('storage', sync);
  }, [key]);
  const running = board && board.started != null && elapsedAt(board, now) < board.moves.length * TRAVEL_MS;
  useEffect(() => {
    if (!running) return;
    const timer = window.setInterval(() => setNow(Date.now()), 100);
    return () => window.clearInterval(timer);
  }, [running]);
  async function transact(update) {
    function apply() {
      const at = Date.now();
      const next = update(read() ?? current.current, at);
      write(next);
      remember(next, at);
      setError('');
      return true;
    }
    try { return navigator.locks ? await navigator.locks.request(key, apply) : apply(); }
    catch (e) { setError(e.message); return false; }
  }
  return { board, now, error, setError, saved, transact };
}

function StoreEditor({ draft, setDraft, board, names, item, submit, cancel }) {
  const move = draft.id != null;
  const available = names.filter(name => !board.stores.some(s => s.name.toLowerCase() === name.toLowerCase()));
  const free = Array.from({ length: CELLS }, (_, i) => i).filter(i => !board.stores.some(s => s.cell === i && s.id !== draft.id));
  return <form className="tr-editor" onSubmit={submit}>
    <h3>{move ? 'Move ' + draft.name : 'New store'}</h3>
    {!move && <><label>Store name<input autoFocus required maxLength={80} list="unplaced-stores" value={draft.name}
      onChange={e => setDraft({ ...draft, name: e.target.value })} /></label>
      <datalist id="unplaced-stores">{available.map(name => <option key={name} value={name} />)}</datalist>
      <label>Opening units<input required type="number" min="0" step="1" value={draft.opening}
        onChange={e => setDraft({ ...draft, opening: e.target.value })} title={board.items[item]} /></label></>}
    <label>Position<select autoFocus={move} value={draft.cell} onChange={e => setDraft({ ...draft, cell: Number(e.target.value) })}>
      {free.map(cell => <option key={cell} value={cell}>{coordinate(cell)}</option>)}</select></label>
    <button type="submit" className="button tr-primary">{move ? 'Save position' : 'Place store'}</button>
    <button type="button" className="settings-toggle" onClick={cancel}>Cancel</button>
  </form>;
}

function StockList({ board, view, item }) {
  return <section className="panel tr-section">
    <table className="tr-stocks"><caption>Simulated stock</caption>
      <thead><tr><th scope="col">Store</th><th scope="col">Position</th><th scope="col">On hand</th></tr></thead>
      <tbody>{board.stores.map(store => <tr key={store.id}><th scope="row"><span className="tr-number" aria-hidden="true">[{String(store.id).padStart(2, '0')}] </span>{store.name}</th>
        <td>{coordinate(store.cell)}</td><td>{view.stock.get(store.id)[item]}</td></tr>)}</tbody>
    </table>
  </section>;
}

function SendForm({ board, view, item, transact }) {
  const [from, setFrom] = useState(board.stores[0]?.id ?? '');
  const [to, setTo] = useState(board.stores[1]?.id ?? '');
  const [quantity, setQuantity] = useState('1');
  const destination = board.stores.find(s => s.id === to && s.id !== from) ?? board.stores.find(s => s.id !== from);
  const available = view.stock.get(from)?.[item] ?? 0;
  function send(event) {
    event.preventDefault();
    transact((value, at) => dispatch(value, { from, to: destination?.id, item, units: Number(quantity) }, at));
  }
  return <section className="panel tr-section"><h2>New transfer</h2>
    <form onSubmit={send} className="tr-send">
      <label>From store<select value={from} onChange={e => setFrom(Number(e.target.value))}>
        {board.stores.map(s => <option key={s.id} value={s.id}>{s.name}</option>)}
      </select></label>
      <label>To store<select value={destination?.id ?? ''} onChange={e => setTo(Number(e.target.value))}>
        {!destination && <option value="">Place another store</option>}
        {board.stores.filter(s => s.id !== from).map(s => <option key={s.id} value={s.id}>{s.name}</option>)}
      </select></label>
      <label>Units<input type="number" min="1" max={available} step="1" required value={quantity}
        onChange={e => setQuantity(e.target.value)} /></label>
      <button type="submit" className="button tr-primary" disabled={Boolean(view.active) || !destination || available === 0}>Send transfer</button>
    </form>
  </section>;
}

function Board({ storageKey, itemName, names }) {
  const { board, now, error, setError, saved, transact } = useBoard(storageKey, itemName, names);
  const [item, setItem] = useState(0);
  const [draft, setDraft] = useState(null);
  const placeButton = useRef(null);
  if (!board) return null;
  const view = snapshot(board, now);
  const active = view.active;
  const last = active ?? board.moves.findLast(move => move.item === item);
  const source = board.stores.find(s => s.id === last?.from);
  const dest = board.stores.find(s => s.id === last?.to);
  const paused = active && board.started == null;
  const free = Array.from({ length: CELLS }, (_, i) => i).find(i => !board.stores.some(store => store.cell === i));
  function choose(cell, store) {
    setError('');
    if (store) setDraft({ id: store.id, name: store.name, cell });
    else setDraft(current => current ? { ...current, cell } : { id: null, name: '', cell, opening: '0' });
  }
  function closeEditor() { setDraft(null); placeButton.current?.focus(); }
  async function save(event) {
    event.preventDefault();
    if (await transact(value => placeStore(value, { ...draft, opening: Number(draft.opening), item }))) closeEditor();
  }
  function control(action) { transact((value, at) => playback(value, action, at)); }
  return <>
    <div className="tr-topline"><span>Inventory simulation</span>
      <label>Item<select value={item} onChange={e => { setItem(Number(e.target.value)); setDraft(null); }}>
        {board.items.map((name, i) => <option key={name} value={i}>{name}</option>)}</select></label>
    </div>
    <section className="panel tr-map-panel">
      <div className="tr-map-head"><h2>Store map</h2>
        <button type="button" className="button" ref={placeButton} disabled={free == null} onClick={() => {
          setDraft({ id: null, name: '', opening: '0', cell: free }); setError('');
        }}>+ Place store</button>
      </div>
      <StoreMap stores={board.stores} item={item} view={view} route={last?.item === item ? last : null} selectedCell={draft?.cell} choose={choose} />
      {draft && <StoreEditor draft={draft} setDraft={setDraft} board={board} names={names} item={item} submit={save} cancel={closeEditor} />}
      <div className="tr-transport"><div className="tr-movement" role="status">
        <span className="tr-status" data-live={Boolean(active)}>{active ? (paused ? 'Paused in transit' : 'In transit') : last ? 'Delivered' : 'Ready'}</span>
        {last && <><span>{last.units} × {board.items[last.item]}</span><span className="tr-journey">{source.name} → {dest.name}</span></>}
      </div><div className="tr-controls">
        {active && <button className="button" onClick={() => control(paused ? 'resume' : 'pause')}>{paused ? 'Resume' : 'Pause'}</button>}
        {Boolean(board.moves.length) && <button className="button" onClick={() => control('replay')}>Replay</button>}
      </div></div>
    </section>
    {!saved && <p className="tr-feedback" role="status">Browser storage is unavailable. This session is temporary.</p>}
    {error && <p className="tr-feedback" role="alert">{error}</p>}
    <div className="tr-bottom"><StockList board={board} view={view} item={item} />
      <SendForm board={board} view={view} item={item} transact={transact} /></div>
  </>;
}

export default function TransfersPage() {
  const { view, loading } = useWorkspace();
  const result = view.result;
  const storageKey = 'stockpilot-transfers-v1:' + (view.projectId ?? 'demo');
  return <div id="transfers-page" className="page-body tr-page">
    <header className="page-head"><h1>Transfers</h1></header>
    {loading && !result ? <p role="status">Opening store map…</p> :
      <Board key={storageKey} storageKey={storageKey} itemName={result?.item}
        names={result?.stores.map(s => s.name) ?? []} />}
  </div>;
}
