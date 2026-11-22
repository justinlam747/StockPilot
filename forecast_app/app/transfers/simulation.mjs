export const COLUMNS = 5;
export const CELLS = COLUMNS * 4;
export const TRAVEL_MS = 8000;
export const DEMO_ITEM = 'Black long cardigan';

export function coordinate(cell) {
  return String.fromCharCode(65 + cell % COLUMNS) + (Math.floor(cell / COLUMNS) + 1);
}

export function createBoard(item, names, now) {
  const items = item ? [item] : [DEMO_ITEM, 'Knit pullover'];
  const storeNames = item ? names.slice(0, 2) : ['Harbour Front', 'Queen West'];
  const stores = storeNames.map((name, i) => ({
    id: i + 1, name, cell: [11, 8][i], opening: items.map((_, j) => (j ? [16, 12] : [32, 8])[i]),
  }));
  // Sales history has no on-hand column. Opening balances are scenario inputs.
  const moves = stores.length === 2 ? [{ from: 1, to: 2, item: 0, units: 6 }] : [];
  return { items, stores, moves, elapsed: 0, started: moves.length ? now : null };
}

export function elapsedAt(board, now) {
  const live = board.started == null ? 0 : Math.max(0, now - board.started);
  return Math.min(board.moves.length * TRAVEL_MS, board.elapsed + live);
}

export function snapshot(board, now) {
  const elapsed = elapsedAt(board, now);
  const arrived = Math.floor(elapsed / TRAVEL_MS);
  const active = board.moves[arrived] ?? null;
  const stock = new Map(board.stores.map(store => [store.id, [...store.opening]]));
  for (let i = 0; i < arrived + (active ? 1 : 0); i++) {
    const move = board.moves[i];
    stock.get(move.from)[move.item] -= move.units;
    if (i < arrived) stock.get(move.to)[move.item] += move.units;
  }
  return { stock, active, arrived, elapsed, progress: (elapsed % TRAVEL_MS) / TRAVEL_MS };
}

function validUnits(value) {
  return Number.isSafeInteger(value) && value >= 0;
}

export function placeStore(board, { id, name, cell, opening, item }) {
  if (!Number.isInteger(cell) || cell < 0 || cell >= CELLS) throw Error('Choose a position on the map.');
  if (board.stores.some(store => store.cell === cell && store.id !== id)) throw Error('That position is occupied.');
  if (id != null) {
    if (!board.stores.some(store => store.id === id)) throw Error('Choose a store on the map.');
    return { ...board, stores: board.stores.map(store => store.id === id ? { ...store, cell } : store) };
  }
  const label = name.trim();
  if (!label || label.length > 80) throw Error('Enter a store name of 1–80 characters.');
  if (board.stores.some(store => store.name.toLowerCase() === label.toLowerCase())) throw Error('That store is already on the map.');
  if (!validUnits(opening) || board.items[item] == null) throw Error('Enter a whole number of opening units.');
  const store = { id: board.stores.length + 1, name: label, cell,
    opening: board.items.map((_, i) => i === item ? opening : 0) };
  return { ...board, stores: [...board.stores, store] };
}

export function dispatch(board, { from, to, item, units }, now) {
  const { stock, active, elapsed } = snapshot(board, now);
  if (active) throw Error('Finish the current transfer first.');
  if (from === to || !stock.has(from) || !stock.has(to)) throw Error('Choose two different stores.');
  if (board.items[item] == null || !validUnits(units) || units < 1) throw Error('Enter a positive whole number of units.');
  if (units > stock.get(from)[item]) throw Error('The source store has insufficient stock.');
  if (!validUnits(stock.get(to)[item] + units)) throw Error('The destination balance would exceed the supported range.');
  return { ...board, moves: [...board.moves, { from, to, item, units }], elapsed, started: now };
}

export function playback(board, action, now) {
  const elapsed = action === 'replay' ? 0 : elapsedAt(board, now);
  return { ...board, elapsed, started: action === 'pause' ? null : now };
}

export function readBoard(storage, key) {
  const raw = storage.getItem(key);
  if (!raw) return null;
  try {
    const board = JSON.parse(raw);
    if (!Array.isArray(board.items) || !board.items.length || !board.items.every(s => typeof s === 'string') ||
        !Array.isArray(board.stores) || board.stores.length > CELLS || !Array.isArray(board.moves) ||
        !validUnits(board.elapsed) || (board.started !== null && !validUnits(board.started))) return null;
    const cells = new Set();
    for (const [i, store] of board.stores.entries()) {
      if (i + 1 !== store.id || typeof store.name !== 'string' || !Number.isInteger(store.cell) ||
          store.cell < 0 || store.cell >= CELLS || cells.has(store.cell) ||
          store.opening.length !== board.items.length || !store.opening.every(validUnits)) return null;
      cells.add(store.cell);
    }
    const balances = board.stores.map(store => [...store.opening]);
    for (const move of board.moves) {
      const source = balances[move.from - 1], dest = balances[move.to - 1];
      if (!Number.isInteger(move.from) || !Number.isInteger(move.to) || !source || !dest || source === dest ||
          !Number.isInteger(move.item) || board.items[move.item] == null ||
          !validUnits(move.units) || move.units < 1 || source[move.item] < move.units || !validUnits(dest[move.item] + move.units)) return null;
      source[move.item] -= move.units;
      dest[move.item] += move.units;
    }
    return board;
  } catch { return null; }
}
