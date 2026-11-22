'use client';

import { useEffect, useMemo, useRef, useState } from 'react';
import { useWorkspace } from '../Workspace';
import { buildReplay, DEMO_FORECAST, ECONOMICS, replayFrame } from './simulation.mjs';
import StoreMap from './StoreMap';
import './transfers.css';

const PHASES = ['dispatch', 'arrival', 'sales'];
const PHASE_MS = [2600, 1300, 1900];
const PHASE_LABEL = { dispatch: 'Dispatch', arrival: 'Arrival', sales: 'Sales' };
const SOURCE_LABEL = { observed: 'Observed sales', forecast: 'Modeled demand', mixed: 'Mixed demand', unknown: 'Demand unavailable' };
const formatWeek = new Intl.DateTimeFormat('en-US', { month: 'short', day: 'numeric', year: 'numeric', timeZone: 'UTC' });
const digits = new Intl.NumberFormat('en-US', { maximumFractionDigits: 1 });
const money = value => (value < 0 ? '−$' : '$') + digits.format(Math.abs(value));
const unitWord = value => Math.abs(value) === 1 ? 'unit' : 'units';
const formatUnits = value => digits.format(value) + ' ' + unitWord(value);

function StoreSelector({ stores, selected, apply }) {
  const [draft, setDraft] = useState(null);
  function toggle(id) {
    setDraft(ids => ids.includes(id) ? ids.filter(key => key !== id) : [...ids, id]);
  }
  return <div className="tr-store-picker">
    <button type="button" className="button" aria-expanded={draft !== null} aria-controls="transfer-stores"
      onClick={() => setDraft(draft === null ? selected : null)}>Choose stores ({selected.length})</button>
    {draft && <section className="tr-picker-panel" id="transfer-stores" aria-label="Stores in replay">
      <div className="tr-picker-actions">
        <button type="button" className="settings-toggle" onClick={() => setDraft(stores.map(s => s.id))}>Select all</button>
        <button type="button" className="settings-toggle" onClick={() => setDraft([])}>Clear</button>
      </div>
      <div className="tr-checkboxes">{stores.map(s => <label key={s.id}><input type="checkbox"
        checked={draft.includes(s.id)} onChange={() => toggle(s.id)} />{s.name}</label>)}</div>
      <div className="tr-picker-actions"><button className="button" disabled={!draft.length} onClick={() => {
        apply(stores.filter(s => draft.includes(s.id)).map(s => s.id)); setDraft(null);
      }}>Apply stores</button><button className="settings-toggle" onClick={() => setDraft(null)}>Cancel</button></div>
    </section>}
  </div>;
}

function usePlayback(weekCount) {
  const [playing, setPlaying] = useState(true);
  const [speed, setSpeed] = useState(1);
  const [position, setPosition] = useState({ step: 0, offset: 0 });
  const positionRef = useRef(position);
  const total = weekCount * PHASES.length;
  const finished = position.step >= total;
  function move(next) { positionRef.current = next; setPosition(next); }
  useEffect(() => {
    if (!playing || finished) return;
    let previous = performance.now();
    const timer = window.setInterval(() => {
      const now = performance.now();
      let { step, offset } = positionRef.current;
      offset += (now - previous) * speed;
      previous = now;
      while (step < total && offset >= PHASE_MS[step % PHASES.length]) {
        offset -= PHASE_MS[step % PHASES.length]; step++;
      }
      move({ step, offset: step === total ? 0 : offset });
    }, 100);
    return () => window.clearInterval(timer);
  }, [playing, finished, speed, total]);
  const step = Math.min(position.step, total - 1);
  return { playing: playing && !finished, finished, week: Math.floor(step / 3), phase: PHASES[step % 3],
    progress: finished ? 1 : position.offset / PHASE_MS[step % 3], speed, setSpeed, toggle: () => setPlaying(p => !p),
    replay() { move({ step: 0, offset: 0 }); setPlaying(true); },
    seek(week) { move({ step: week * 3, offset: 0 }); setPlaying(false); } };
}

function Transport({ clock, weeks, week }) {
  return <div className="tr-transport">
    <div className="tr-play">
      {clock.finished ? <button className="button" onClick={clock.replay}>Replay</button> : <>
        <button className="button tr-play-primary" onClick={clock.toggle}>{clock.playing ? 'Pause' : 'Resume'}</button>
        <button className="settings-toggle" onClick={clock.replay}>Replay</button>
      </>}
      <label>Speed<select value={clock.speed} onChange={e => clock.setSpeed(Number(e.target.value))}>
        {[1, 2, 4].map(v => <option key={v} value={v}>{v}×</option>)}
      </select></label>
    </div>
    <label className="tr-week-slider"><span>Week {clock.week + 1} / {weeks.length}</span>
      <input aria-label="Replay week" type="range" min="1" max={weeks.length} value={clock.week + 1}
        onChange={e => clock.seek(Number(e.target.value) - 1)} aria-valuetext={week.date} /></label>
  </div>;
}

function Savings({ frame }) {
  return <dl className="tr-metrics">
    <div className="tr-net"><dt>Estimated money saved</dt><dd>{money(frame.saved)}</dd></div>
    <div><dt>Net sales recovered</dt><dd>{digits.format(frame.recoveredUnits)} <small>{unitWord(frame.recoveredUnits)}</small></dd></div>
    <div><dt>Transfer cost</dt><dd>{money(frame.transferCost)}</dd></div>
  </dl>;
}

function Shipments({ week, names, phase }) {
  return <section className="tr-shipments">
    <div className="tr-section-head"><h3>Shipments this week</h3><span>{week.moves.length}</span></div>
    {week.moves.length ? <ul>{week.moves.map(move =>
      <li key={JSON.stringify([move.from, move.to])}><span><b>{names.get(move.from)}</b> → {names.get(move.to)}</span>
        <span>{formatUnits(move.units)} · {phase === 'dispatch' ? 'in transit' : 'received'}</span></li>)}</ul> :
      <p className="tr-quiet">No shipments this week.</p>}
  </section>;
}

function Replay({ network }) {
  const clock = usePlayback(network.weeks.length);
  const week = network.weeks[clock.week];
  const frame = useMemo(() => replayFrame(network, clock.week, clock.phase), [network, clock.week, clock.phase]);
  const names = useMemo(() => new Map(network.stores.map(s => [s.id, s.name])), [network]);
  return <>
    <section className="panel tr-map-panel" aria-label="Store transfer replay">
      <div className="tr-map-header"><div><h2>Store network</h2>
        <span className="tr-date">{formatWeek.format(new Date(week.date + 'T00:00:00Z'))}</span></div>
        <div className="tr-week-status"><span className="tr-phase">{clock.finished ? 'Complete' : PHASE_LABEL[clock.phase]}</span>
          <span>{formatUnits(frame.inTransit)} in transit</span></div></div>
      <StoreMap stocks={frame.stocks} maxOnHand={network.maxOnHand} moves={week.moves}
        phase={clock.phase} progress={clock.progress} />
      <Transport clock={clock} weeks={network.weeks} week={week} />
    </section>
    <Savings frame={frame} />
    <div className="tr-ledger"><section className="tr-comparison">
      <div className="tr-section-head"><h3>Cumulative sales</h3><span>{SOURCE_LABEL[week.demandSource]} this week</span></div>
      <dl><div><dt>With transfers</dt><dd>{formatUnits(frame.sold)}</dd></div>
        <div><dt>Without transfers</dt><dd>{formatUnits(frame.baselineSold)}</dd></div></dl>
    </section><Shipments week={week} names={names} phase={clock.phase} /></div>
  </>;
}

function HowItWorks() {
  return <section className="tr-method" aria-labelledby="transfer-method"><h2 id="transfer-method">How it works</h2>
    <p>Each week, XGBoost forecasts demand for each store. Stores keep nine days of forecast stock and offer surplus to stores below one week of demand. Shipments arrive before sales are counted.</p>
    <p>Stores start with half to two weeks of forecast stock. Every other week they receive twice the prior weekly forecast. Both scenarios use these same supplies.</p>
    <p>In-stock sales measure historical demand. A missing actual uses the forecast. A stockout uses the higher of recorded sales and the rounded forecast.</p><p>Estimated savings equal extra units sold versus keeping stock in place, times {money(ECONOMICS.unitMargin)} contribution per unit, less {money(ECONOMICS.unitTransferCost)} per unit moved. Storefront size shows current on-hand inventory.</p>
  </section>;
}

function Scenario({ result, demo }) {
  const [selected, setSelected] = useState(() => result.stores.slice(0, 4).map(store => store.id));
  const network = useMemo(() => buildReplay(result, selected), [result, selected]);
  return <>
    <div className="tr-scenario"><div><span className="tr-source">{demo ? 'Demo forecast · synthetic sales' : 'Saved forecast'}</span>
      <h2>{result.item}</h2></div><StoreSelector stores={result.stores} selected={selected} apply={setSelected} /></div>
    {network.weeks.length && network.stores.length ? <Replay key={JSON.stringify(selected)} network={network} /> :
      <p className="panel tr-empty">No forecast weeks are available for these stores.</p>}
    <HowItWorks />
  </>;
}

export default function TransfersPage() {
  const { view, loading } = useWorkspace();
  return <div id="transfers-page" className="page-body tr-page">
    <header className="page-head"><h1>Transfers</h1></header>
    {loading && !view.result ? <p role="status">Opening forecast…</p> :
      <Scenario key={JSON.stringify([view.projectId, view.jobId])}
        result={view.result ?? DEMO_FORECAST} demo={!view.result} />}
  </div>;
}
