import assert from 'node:assert/strict';
import {mkdtemp, rm} from 'node:fs/promises';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import test from 'node:test';

import {GET, POST} from '../forecast_app/app/api/forecast/route.js';
import {closeForecastQueues} from '../forecast_app/server/forecast-queue.mjs';
import {startLocalBroker} from '../scripts/queue-broker.mjs';
const address = 'http://127.0.0.1:3000/api/forecast';
const headers = {host: '127.0.0.1:3000', 'content-type': 'application/json'};
const upload = body => new Request(address, {
  method: 'POST', headers, body: JSON.stringify(body),
});

test('local worker selects an item, trains it and restores its saved forecast in a fresh process', async () => {
  const dir = await mkdtemp(join(tmpdir(), 'stockpilot-forecast-test-'));
  const broker = await startLocalBroker({directory: join(dir, 'broker')});
  const previousBroker = process.env.STOCKPILOT_REDIS_URL;
  process.env.STOCKPILOT_REDIS_URL = broker.url;
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
    const invalidSettings = await POST(upload({csv: dataset.join('\n'), parameters: {max_depth: '4'}}));
    assert.equal(invalidSettings.status, 422);
    const trained = await POST(upload({csv: dataset.join('\n'), item: 'Cardigan', parameters: {max_depth: 4}}));
    const snapshot = await trained.json();
    assert.equal(trained.status, 200, snapshot.error);
    assert.deepEqual(snapshot.result.models.map(m => m.id), ['xgboost']);
    assert.equal(snapshot.result.training.parameters.max_depth, 4);
    assert.equal(snapshot.result.training.parameters.n_estimators, 40);
    assert.equal(snapshot.result.scores[0].count, 3);
    assert.equal(snapshot.result.next, null);
    assert.deepEqual(snapshot.result.forecastRange, {start: '2025-02-03', end: '2025-02-24'});
    assert.equal(snapshot.result.source.availability, 'reported');
    const restored = await GET(new Request(address, {headers}));
    assert.equal(restored.status, 200);
    assert.deepEqual((await restored.json()).result, snapshot.result);

    const active = {projectId: snapshot.projectId};
    const rerun = await POST(upload(active));
    assert.equal(rerun.status, 200);
    assert.deepEqual((await rerun.json()).result, snapshot.result);
    assert.equal((await POST(upload({...active, csv: dataset.join('\n')}))).status, 400);
    assert.equal((await POST(upload({projectId: '9'.repeat(64)}))).status, 404);
    assert.equal((await POST(upload({...active, forecastStart: '2025-03-03'}))).status, 422);
    const jobsBefore = (await (await GET(new Request(address + '?queue=1', {headers}))).json()).jobs.length;
    const outside = await POST(upload({...active, forecastStart: '2025-02-24', forecastEnd: '2025-03-03'}));
    assert.equal(outside.status, 422);
    const early = await POST(upload({...active, forecastStart: '2025-01-20', forecastEnd: '2025-02-03'}));
    assert.equal(early.status, 422);
    const jobsAfter = (await (await GET(new Request(address + '?queue=1', {headers}))).json()).jobs.length;
    assert.equal(jobsAfter, jobsBefore, 'Invalid periods must be rejected before adding a job');
    const dated = await POST(upload({...active, forecastStart: '2025-02-17', forecastEnd: '2025-02-24'}));
    assert.equal(dated.status, 200);
    const fixed = (await dated.json()).result;
    assert.equal(fixed.next, null);
    assert.equal(fixed.training.parameters.max_depth, 4);
    assert.deepEqual(fixed.weeks.map(frame => frame.week), ['2025-02-17', '2025-02-24']);
    assert.ok(fixed.weeks.every(frame => frame.stores.every(row => Number.isFinite(row.actual))));
  } finally {
    await closeForecastQueues();
    await broker.stop();
    if (previousBroker === undefined) delete process.env.STOCKPILOT_REDIS_URL;
    else process.env.STOCKPILOT_REDIS_URL = previousBroker;
    if (previousDir === undefined) delete process.env.STOCKPILOT_DATA_DIR;
    else process.env.STOCKPILOT_DATA_DIR = previousDir;
    await rm(dir, {recursive: true, force: true});
  }
});
