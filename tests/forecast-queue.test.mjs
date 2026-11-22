import assert from 'node:assert/strict';
import {mkdtemp, rm} from 'node:fs/promises';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {setTimeout as delay} from 'node:timers/promises';
import test from 'node:test';
import {GET, POST} from '../forecast_app/app/api/forecast/route.js';
import {closeForecastQueues, forecastQueue} from '../forecast_app/server/forecast-queue.mjs';
import {startLocalBroker} from '../scripts/queue-broker.mjs';

const address = 'http://localhost:3000/api/forecast';
const headers = {host:'localhost:3000', 'content-type':'application/json'};
const get = async query => (await GET(new Request(address + query, {headers}))).json();

function csv(item, weeks = 8) {
  const rows = ['week,item,store,units_sold'];
  for (let i = 0; i < weeks; i++) {
    const week = new Date(Date.UTC(2025, 0, 6 + 7 * i)).toISOString().slice(0, 10);
    rows.push([week, item, 'West', 2 + i].join(','));
  }
  return rows.join('\n');
}

async function submit(item, weeks, async = true, signal) {
  const response = await POST(new Request(address, {
    method:'POST', signal, headers:{...headers, ...(async ? {prefer:'respond-async'} : {})},
    body:JSON.stringify({csv:csv(item, weeks)}),
  }));
  const body = await response.json();
  assert.equal(response.status, async ? 202 : 200, body.error);
  return async ? body.job : body;
}

async function finished(id) {
  const timeout = Date.now() + 90000;
  while (Date.now() < timeout) {
    const result = await get('?job=' + id + '&result=1');
    if (result.job?.status === 'completed' || result.job?.status === 'failed') return result;
    await delay(70);
  }
  assert.fail('Forecast job did not finish');
}

test('forecast requests survive restart and disconnect, drain in FIFO order, and open independent results', async () => {
  const dir = await mkdtemp(join(tmpdir(), 'stockpilot-job-test-'));
  const config = {directory: join(dir, 'broker')};
  let broker = await startLocalBroker(config);
  const previous = {...process.env};
  Object.assign(process.env, {STOCKPILOT_DATA_DIR:dir, STOCKPILOT_REDIS_URL:broker.url, STOCKPILOT_DISABLE_PEERS:'1'});
  try {
    const original = await submit('Current selection', 8, false);
    const service = await forecastQueue();
    await service.queue.pause();
    const browser = new AbortController();
    const first = await submit('Blue cardigan', 8, true, browser.signal);
    browser.abort();
    const bad = await submit('Short history', 1);
    const last = await submit('Black cardigan', 8);
    const {jobs} = await get('?queue=1');
    assert.deepEqual(jobs.filter(job => job.status === 'queued').map(job => job.id), [first.id, bad.id, last.id]);
    assert.deepEqual(jobs[0].models, [{id:'xgboost',status:'queued'}]);
    assert.ok(!JSON.stringify(jobs).includes('units_sold'));
    assert.equal((await get('?job=..%2F..%2Fa')).error, 'The forecast job was not found.');
    await closeForecastQueues();
    await broker.stop();
    broker = await startLocalBroker(config);
    process.env.STOCKPILOT_REDIS_URL = broker.url;
    const restarted = await forecastQueue();
    await restarted.queue.resume();
    const [a,b,c] = await Promise.all([first, bad, last].map(job => finished(job.id)));
    assert.equal(a.snapshot.result.item, 'Blue cardigan');
    assert.equal(b.job.status, 'failed');
    assert.ok(b.job.error);
    assert.equal(c.snapshot.result.item, 'Black cardigan');
    assert.ok(a.job.finishedAt <= b.job.startedAt && b.job.finishedAt <= c.job.startedAt);
    assert.deepEqual(a.job.models, [{id:'xgboost',status:'completed'}]);
    assert.equal(b.job.models[0].status, 'failed');
    assert.equal((await get('')).projectId, original.projectId);
    assert.equal((await get('?job=' + first.id + '&result=1&activate=1')).snapshot.projectId, a.job.projectId);
    assert.equal((await get('')).result.item, 'Blue cardigan');
    assert.equal((await get('?job=' + last.id + '&result=1')).snapshot.result.item, 'Black cardigan');
  } finally {
    await closeForecastQueues();
    await broker.stop();
    for (const name of ['STOCKPILOT_DATA_DIR','STOCKPILOT_REDIS_URL','STOCKPILOT_DISABLE_PEERS']) {
      if (previous[name] === undefined) delete process.env[name];
      else process.env[name] = previous[name];
    }
    await rm(dir, {recursive:true, force:true});
  }
});
