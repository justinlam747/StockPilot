import { memo, useEffect, useMemo, useRef, useState } from 'react';

const ZOOM = [0.6, 0.8, 1, 1.25, 1.5, 2];
const ROW = 155;
const SHOP = [
  '   ___________   ',
  '  /___________\\  ',
  '  | S H O P   |  ',
  ' /_/_/_/_/_/_/_\\ ',
  '  | [==] .--. |  ',
  '  | [__] | o| |  ',
  "  '------'--'-'  ",
];
const units = new Intl.NumberFormat('en-US');
const unitCount = value => units.format(value) + (value === 1 ? ' unit' : ' units');

function positions(stocks, width, maxOnHand) {
  const columns = Math.max(1, Math.min(Math.ceil(Math.sqrt(stocks.length)), Math.floor(width / 153), 6));
  const cell = width / columns;
  const maximum = Math.log1p(Math.max(1, maxOnHand));
  return stocks.map(({ onHand }, index) => {
    // A fixed log scale keeps a few units visible beside stores holding hundreds.
    const stockSize = onHand ? 0.67 + 0.74 * Math.log1p(onHand) / maximum : 0.56;
    const size = stockSize * Math.min(1, cell / 179);
    return {
      x: (index % columns + 0.5) * cell, y: Math.floor(index / columns) * ROW + 96,
      col: index % columns, row: Math.floor(index / columns), size, port: 54 * size + 3,
    };
  });
}

// All paths follow the lanes between storefronts, keeping labels clear even on large maps.
function routeBetween(a, b, cell) {
  const left = a.col <= b.col ? 1 : -1;
  if (a.row === b.row) return [
    [a.x + left * a.port, a.y - 18], [a.x + left * cell / 2, a.y - 18],
    [a.x + left * cell / 2, a.y - 91], [b.x - left * cell / 2, b.y - 91],
    [b.x - left * cell / 2, b.y - 18], [b.x - left * b.port, b.y - 18],
  ].filter((_, i) => Math.abs(a.col - b.col) !== 1 || i === 0 || i === 5);
  const lane = a.col === b.col ? a.x + cell * 0.46 : a.x + left * cell / 2;
  const arriveLane = a.col === b.col ? lane : b.x - left * cell / 2;
  const endSide = a.col === b.col ? 1 : -left;
  const cross = a.row < b.row ? b.y - 91 : b.y + 44;
  return [
    [a.x + left * a.port, a.y - 18], [lane, a.y - 18], [lane, cross],
    [arriveLane, cross], [arriveLane, b.y - 18], [b.x + endSide * b.port, b.y - 18],
  ];
}

function parcelPosition(route, progress) {
  const distances = route.slice(1).map((p, i) => Math.abs(p[0] - route[i][0]) + Math.abs(p[1] - route[i][1]));
  let remaining = progress * distances.reduce((sum, length) => sum + length, 0);
  for (let i = 0; i < distances.length; i++) {
    const length = distances[i];
    if (length && remaining <= length) {
      const t = remaining / length;
      return route[i].map((v, axis) => v + t * (route[i + 1][axis] - v));
    }
    remaining -= length;
  }
  return route.at(-1);
}

const Storefront = memo(function Storefront({ store, point, maxLabel }) {
  const { onHand, forecast, name } = store;
  const size = point.size;
  const label = name.length > maxLabel ? name.slice(0, maxLabel - 1) + '…' : name;
  const title = name + ', ' + unitCount(onHand) + ' on hand' +
    (forecast == null ? '' : ', weekly forecast ' + unitCount(forecast));
  return <g className="tr-shop" data-store-id={store.id} data-on-hand={onHand} role="img" aria-label={title}
    transform={'translate(' + point.x + ' ' + point.y + ')'}>
    <title>{title}</title>
    <g transform={'scale(' + size + ')'} data-stock-scale={size} className="tr-store-art" data-empty={!onHand}>
      <text textAnchor="middle" xmlSpace="preserve">{SHOP.map((line, i) =>
        <tspan x="0" y={(i - SHOP.length + 1) * 10.2} key={i}>{line}</tspan>)}</text>
    </g>
    <text y="17" textAnchor="middle" className="tr-store-name">{label}</text>
    <text y="34" textAnchor="middle" className="tr-store-units">{units.format(onHand)} on hand</text>
  </g>;
});

const MapBase = memo(function MapBase({ stocks, points, width, height, cell, routes }) {
  const maxLabel = Math.max(10, Math.floor((cell - 13) / 7.6));
  return <>
    <defs><pattern id="tr-dot-field" width="14" height="14" patternUnits="userSpaceOnUse">
      <circle cx="1" cy="1" r=".8" fill="var(--rule)" />
    </pattern></defs>
    <rect width={width} height={height} fill="url(#tr-dot-field)" />
    <g className="tr-routes" aria-hidden="true">{routes.map(({ key, route }) =>
      <polyline key={key} points={route.map(p => p.join(',')).join(' ')} />)}</g>
    {stocks.map((store, i) => <Storefront key={store.id} store={store} point={points[i]} maxLabel={maxLabel} />)}
  </>;
});

export default function StoreMap({ stocks, maxOnHand, moves, phase, progress }) {
  const viewport = useRef(null);
  const [available, setAvailable] = useState(720);
  const [zoomIndex, setZoomIndex] = useState(2);
  useEffect(() => {
    const element = viewport.current;
    function measure() { setAvailable(element.clientWidth || 720); }
    measure();
    const observer = new ResizeObserver(measure);
    observer.observe(element);
    return () => observer.disconnect();
  }, []);
  const width = Math.max(160, available);
  const points = useMemo(() => positions(stocks, width, maxOnHand), [stocks, width, maxOnHand]);
  const cell = points[0].x * 2;
  const height = (points.at(-1).row + 1) * ROW;
  const routes = useMemo(() => {
    const byId = new Map(stocks.map((store, i) => [store.id, points[i]]));
    return moves.map(move => ({
      key: JSON.stringify([move.from, move.to]),
      route: routeBetween(byId.get(move.from), byId.get(move.to), cell),
    }));
  }, [moves, stocks, points, cell]);
  function reset() {
    setZoomIndex(2);
    viewport.current.scrollTo(0, 0);
  }
  const zoom = ZOOM[zoomIndex];
  return <div className="tr-map">
    <div className="tr-map-toolbar"><span className="tr-legend"><i aria-hidden="true" />Transfer route</span>
      <div className="tr-zoom" role="group" aria-label="Map zoom">
        <button type="button" aria-label="Zoom out" onClick={() => setZoomIndex(i => i - 1)} disabled={zoomIndex === 0}>−</button>
        <span>{Math.round(zoom * 100)}%</span>
        <button type="button" aria-label="Zoom in" onClick={() => setZoomIndex(i => i + 1)} disabled={zoomIndex === ZOOM.length - 1}>+</button>
        <button type="button" onClick={reset} aria-label="Reset map zoom">Reset</button>
      </div>
    </div>
    <div ref={viewport} tabIndex="0" role="region" aria-label="Store map" className="tr-map-viewport">
      <svg viewBox={'0 0 ' + width + ' ' + height} width={width * zoom} height={height * zoom}
        aria-label="Stores and transfer routes" role="group">
        <MapBase stocks={stocks} points={points} width={width} height={height} cell={cell} routes={routes} />
        {phase === 'dispatch' && routes.map(({ key, route }) => {
          const [x, y] = parcelPosition(route, progress);
          return <g key={key} className="tr-parcel" aria-hidden="true" transform={'translate(' + x + ' ' + y + ')'}>
            <rect x="-10" y="-6" width="20" height="13" rx="1" /><text x="0" y="4" textAnchor="middle">[#]</text>
          </g>;
        })}
      </svg>
    </div>
  </div>;
}
