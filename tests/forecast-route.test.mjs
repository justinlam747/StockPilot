import assert from 'node:assert/strict';
import {mkdtemp, readFile, rm} from 'node:fs/promises';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import test from 'node:test';

// Next compiles route.js as ESM, including in checkouts whose root has no module type.
const source = await readFile(new URL('../forecast_app/app/api/forecast/route.js', import.meta.url));
const {GET, POST} = await import('data:text/javascript;base64,' + source.toString('base64'));
const address = 'http://127.0.0.1:3000/api/forecast';
const headers = {host: '127.0.0.1:3000', 'content-type': 'application/json'};
const upload = (body, extra = {}) => new Request(address, {
  method: 'POST', headers: {...headers, ...extra}, body: typeof body === 'string' ? body : JSON.stringify(body),
});

test('local API protects personal projects and validates request size and encoding', async () => {
  assert.equal((await GET(new Request(address, {headers: {host: 'example.com'}}))).status, 403);
  assert.equal((await POST(upload({}, {origin: 'https://example.com'}))).status, 403);
  assert.equal((await POST(upload({}, {'sec-fetch-site': 'cross-site'}))).status, 403);
  assert.equal((await POST(upload({}, {'content-type': 'text/plain'}))).status, 415);
  assert.equal((await POST(upload('malformed'))).status, 400);
  assert.equal((await POST(upload({csv: 'a'.repeat(1024 * 1024 + 1)}))).status, 413);
});

test('local worker selects an item, trains it and restores its saved forecast in a fresh process', async () => {
  const dir = await mkdtemp(join(tmpdir(), 'stockpilot-forecast-test-'));
  const previousDir = process.env.STOCKPILOT_DATA_DIR;
  process.env.STOCKPILOT_DATA_DIR = dir;
  try {
    const saved = await GET(new Request(address, {headers}));
    assert.equal(saved.status, 200);
    assert.equal(saved.headers.get('cache-control'), 'no-store');
    assert.deepEqual(await saved.json(), {projects: [], projectId: null, result: null, savedAt: null});
    const choice = await POST(upload({csv: 'week,item,store,units\n2025-01-06,A,S,0\n2025-01-06,B,S,5'}));
    assert.equal(choice.status, 200);
    assert.deepEqual((await choice.json()).items, [{id: 'A', name: 'A'}, {id: 'B', name: 'B'}]);
    const invalid = await GET(new Request(address + '?id=../../a', {headers}));
    assert.equal(invalid.status, 422);
    const unknown = await GET(new Request(address + '?id=' + 'a'.repeat(64), {headers}));
    assert.equal(unknown.status, 404);
    const dataset = ['week,item,store,units_sold,in_stock'];
    for (let i = 0; i < 8; i++) {
      const monday = new Date(Date.UTC(2025, 0, 6 + 7 * i)).toISOString().slice(0, 10);
      dataset.push(monday + ',Cardigan,Queen West,' + (i + 2) + ',' + (i !== 6));
    }
    dataset.push('2025-01-06,Scarf,Queen West,1,true');
    const trained = await POST(upload({csv: dataset.join('\n'), item: 'Cardigan'}));
    const snapshot = await trained.json();
    assert.equal(trained.status, 200, snapshot.error);
    assert.deepEqual(snapshot.result.models.map(m => m.id), ['xgboost']);
    assert.equal(snapshot.result.scores[0].count, 3);
    assert.equal(snapshot.result.next.week, '2025-03-03');
    assert.equal(snapshot.result.source.availability, 'reported');
    const restored = await GET(new Request(address, {headers}));
    assert.equal(restored.status, 200);
    assert.deepEqual((await restored.json()).result, snapshot.result);
  } finally {
    if (previousDir === undefined) delete process.env.STOCKPILOT_DATA_DIR;
    else process.env.STOCKPILOT_DATA_DIR = previousDir;
    await rm(dir, {recursive: true, force: true});
  }
});
