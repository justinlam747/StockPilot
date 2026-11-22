import { COLUMNS, CELLS, coordinate } from './simulation.mjs';

const cellNumbers = Array.from({ length: CELLS }, (_, i) => i);
const center = cell => ({ x: (cell % COLUMNS + .5) * 100, y: (Math.floor(cell / COLUMNS) + .5) * 75 });

function Route({ from, to, progress, moving }) {
  const a = center(from.cell), b = center(to.cell);
  const dx = b.x - a.x, dy = b.y - a.y;
  const turn = a.x + dx / 2;
  const half = Math.abs(dx / 2), vertical = Math.abs(dy);
  const distance = (half * 2 + vertical) * progress;
  let x = a.x, y = a.y;
  if (distance < half) x += Math.sign(dx) * distance;
  else if (distance < half + vertical) {
    x = turn;
    y += Math.sign(dy) * (distance - half);
  } else {
    x = turn + Math.sign(dx) * (distance - half - vertical);
    y = b.y;
  }
  return <>
    <svg className="tr-route" data-moving={moving} viewBox="0 0 500 300" preserveAspectRatio="none" aria-hidden="true">
      <path d={`M ${a.x} ${a.y} H ${turn} V ${b.y} H ${b.x}`} />
    </svg>
    {moving && <span aria-hidden="true" className="tr-parcel" style={{ left: (x / 5) + '%', top: (y / 3) + '%' }}>[#]</span>}
  </>;
}

export default function StoreMap({ stores, item, view, route, selectedCell, choose }) {
  const from = stores.find(s => s.id === route?.from);
  const to = stores.find(s => s.id === route?.to);
  return <div className="tr-map" role="group" aria-label="Store map">
    <div className="tr-cols" aria-hidden="true">{['A', 'B', 'C', 'D', 'E'].map(c => <span key={c}>{c}</span>)}</div>
    <div className="tr-rows" aria-hidden="true">{[1, 2, 3, 4].map(r => <span key={r}>{r}</span>)}</div>
    <div className="tr-field">
      <svg className="tr-dots" width="100%" height="100%" aria-hidden="true">
        <defs><pattern id="transfer-dot" width="15" height="15" patternUnits="userSpaceOnUse">
          <text x="4" y="7" fontSize="10">.</text>
        </pattern></defs>
        <rect width="100%" height="100%" fill="url(#transfer-dot)" />
      </svg>
      {from && to && <Route from={from} to={to} progress={view.progress} moving={Boolean(view.active)} />}
      {cellNumbers.map(cell => {
        const store = stores.find(s => s.cell === cell);
        const label = store ? 'Move ' + store.name + ' from ' + coordinate(cell) : 'Place store at ' + coordinate(cell);
        return <button key={cell} type="button" className="tr-cell" data-selected={selectedCell === cell || undefined}
          title={label} aria-label={label} onClick={() => choose(cell, store)}>
          {store ? <span className="tr-node" data-on-route={store.id === from?.id || store.id === to?.id || undefined}>
            <span className="tr-store-glyph">[{String(store.id).padStart(2, '0')}]</span>
            <span className="tr-store-name">{store.name}</span>
            <span className="tr-node-units">{view.stock.get(store.id)[item]} u</span>
          </span> : <span className="tr-empty-cell" aria-hidden="true">[+]</span>}
        </button>;
      })}
    </div>
  </div>;
}
