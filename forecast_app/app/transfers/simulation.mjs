export const ECONOMICS = Object.freeze({ unitMargin: 12, unitTransferCost: 1 });
const OPENING_COVER = [2, 0.5, 1.5, 0.75];
const DONOR_COVER_DAYS = 9; // One week of predicted sales plus two safety days.

// Walk-forward XGBoost output from stockpilot_local.xgb.train_item on 16 synthetic
// weeks per store. Columns are date, observed unit sales, and predicted unit sales.
const demoNames = ['Harbour Front', 'Queen West', 'The Annex', 'Leslieville', 'Yorkville', 'North York'];
const demoHistory = [
  ['2025-10-20', [14, 12, 12, 10, 9, 5], [11.03, 9.621, 14.939, 9.304, 11.487, 7.096]],
  ['2025-10-27', [10, 8, 16, 9, 17, 3], [12.723, 9.473, 15.079, 9.378, 10.953, 8.036]],
  ['2025-11-03', [18, 6, 15, 5, 10, 10], [12.397, 10.207, 13.62, 9.062, 10.013, 6.908]],
  ['2025-11-10', [11, 13, 17, 10, 8, 6], [10.944, 9.561, 14.669, 8.447, 11.357, 7.363]],
  ['2025-11-17', [9, 9, 16, 6, 12, 8], [11.279, 9.473, 13.76, 8.717, 10.606, 7.43]],
  ['2025-11-24', [13, 11, 18, 7, 11, 4], [11.108, 10.437, 14.371, 8.791, 8.854, 7.418]],
  ['2025-12-01', [12, 7, 14, 8, 16, 9], [10.649, 10.471, 14.705, 8.715, 8.859, 7.345]],
  ['2025-12-08', [17, 12, 12, 7, 9, 8], [11.674, 10.07, 14.735, 8.904, 11.161, 7.576]],
  ['2025-12-15', null, [12.149, 10.068, 14.97, 8.807, 11.805, 7.75]],
];
const demoWeeks = demoHistory.map(([week, actual, predictions]) => ({
  week, stores: demoNames.map((id, i) => ({ id, actual: actual?.[i] ?? null, available: actual ? true : null,
    forecasts: { xgboost: predictions[i] } })),
}));
export const DEMO_FORECAST = {
  item: 'Black long cardigan', stores: demoNames.map(name => ({ id: name, name })),
  weeks: demoWeeks.slice(0, -1), next: demoWeeks.at(-1),
};

function nonnegative(value) {
  return Number.isFinite(value) && value >= 0 ? value : null;
}

function demandFor(observation, forecast) {
  const actual = nonnegative(observation?.actual);
  if (actual !== null && observation.available !== false) return { units: actual, source: 'observed' };
  if (forecast !== null) return { units: Math.max(actual ?? 0, Math.round(forecast)), source: 'forecast' };
  // Without a usable forecast, constrained sales are only a lower bound on demand.
  return { units: actual, source: 'unknown' };
}

function planMoves(positions) {
  const donors = [], receivers = [];
  for (const p of positions) {
    if (p.forecast === null) continue;
    const deficit = Math.ceil(p.forecast) - p.start;
    const surplus = p.start - Math.ceil(p.forecast * DONOR_COVER_DAYS / 7);
    if (deficit > 0) receivers.push({ p, remaining: deficit });
    if (surplus > 0) donors.push({ p, remaining: surplus });
  }
  donors.sort((a, b) => b.remaining - a.remaining);
  receivers.sort((a, b) => b.remaining - a.remaining);
  const moves = [];
  let donorIndex = 0;
  for (const receiver of receivers) {
    while (receiver.remaining && donorIndex < donors.length) {
      const donor = donors[donorIndex];
      const units = Math.min(donor.remaining, receiver.remaining);
      moves.push({ from: donor.p.id, to: receiver.p.id, units });
      donor.p.outgoing += units;
      receiver.p.incoming += units;
      receiver.remaining -= units;
      donor.remaining -= units;
      if (!donor.remaining) donorIndex++;
    }
  }
  return moves;
}

function prepareStore(store, observation, weekIndex, prior) {
  const forecast = nonnegative(observation?.forecasts?.xgboost);
  const opening = Math.round((forecast ?? 0) * OPENING_COVER[store.index % OPENING_COVER.length]);
  const receiptDue = weekIndex > 0 && weekIndex % 2 === store.index % 2;
  const receipt = receiptDue ? Math.round(2 * (prior.forecast ?? 0)) : 0;
  return {
    id: store.id, name: store.name, forecast, receipt, incoming: 0, outgoing: 0,
    start: (prior?.closing ?? opening) + receipt,
    baselineStart: (prior?.baselineClosing ?? opening) + receipt,
  };
}

function settleWeek(positions, observations, priorTotals) {
  const totals = { ...priorTotals };
  const sources = new Set();
  for (const p of positions) {
    const demand = demandFor(observations.get(p.id), p.forecast);
    sources.add(demand.source);
    const units = demand.units ?? 0;
    const available = p.start - p.outgoing + p.incoming;
    const sold = Math.min(available, units);
    const baselineSold = Math.min(p.baselineStart, units);
    p.closing = available - sold;
    p.baselineClosing = p.baselineStart - baselineSold;
    totals.sold += sold;
    totals.baselineSold += baselineSold;
    totals.missedUnits += units - sold;
    totals.baselineMissedUnits += units - baselineSold;
    totals.transferCost += p.outgoing * ECONOMICS.unitTransferCost;
  }
  const demandSource = sources.size === 1 ? [...sources][0] : 'mixed';
  return { totals, demandSource };
}

export function buildReplay(result = DEMO_FORECAST, selectedIds) {
  const selected = selectedIds ? new Set(selectedIds) : null;
  const stores = result.stores.map((store, index) => ({ ...store, index }))
    .filter(store => !selected || selected.has(store.id));
  const weeks = [];
  let maxOnHand = 0;
  let priorTotals = { sold: 0, baselineSold: 0, missedUnits: 0, baselineMissedUnits: 0, transferCost: 0 };
  const forecasts = result.next ? [...result.weeks, result.next] : result.weeks;
  for (const forecast of forecasts) {
    if (!stores.length) break;
    const observations = new Map(forecast.stores.map(row => [row.id, row]));
    const prior = weeks.at(-1)?.positions;
    const positions = stores.map((store, i) => prepareStore(store, observations.get(store.id), weeks.length, prior?.[i]));
    // Both the opening allocation and the planner have only information available before sales.
    const moves = planMoves(positions);
    const { totals, demandSource } = settleWeek(positions, observations, priorTotals);
    for (const p of positions) maxOnHand = Math.max(maxOnHand, p.start, p.start - p.outgoing + p.incoming);
    weeks.push({ date: forecast.week, moves, positions, priorTotals, totals, demandSource });
    priorTotals = totals;
  }
  return { item: result.item, stores, weeks, maxOnHand };
}

export function replayFrame(replay, weekIndex, phase) {
  const week = replay.weeks[weekIndex];
  const arrived = phase !== 'dispatch';
  const settled = phase === 'sales';
  const counts = settled ? week.totals : week.priorTotals;
  const transferCost = week.totals.transferCost;
  const recoveredUnits = counts.sold - counts.baselineSold;
  return {
    ...counts, transferCost, recoveredUnits, saved: recoveredUnits * ECONOMICS.unitMargin - transferCost,
    inTransit: arrived ? 0 : week.moves.reduce((n, move) => n + move.units, 0),
    stocks: week.positions.map(p => ({
      id: p.id, name: p.name, forecast: p.forecast,
      onHand: settled ? p.closing : p.start - p.outgoing + (arrived ? p.incoming : 0),
      baselineOnHand: settled ? p.baselineClosing : p.baselineStart,
    })),
  };
}
