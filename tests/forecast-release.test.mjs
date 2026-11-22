import assert from 'node:assert/strict';
import { spawn, spawnSync } from 'node:child_process';
import { mkdtemp, readFile, readdir, rm } from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import test from 'node:test';
import { fileURLToPath } from 'node:url';
import { startLocalBroker } from '../scripts/queue-broker.mjs';

const root = fileURLToPath(new URL('../', import.meta.url));
const app = path.join(root, 'forecast_app');
const python = process.env.STOCKPILOT_PYTHON ||
  path.join(root, '.venv', process.platform === 'win32' ? 'Scripts/python.exe' : 'bin/python');
const template = 'weekly-sales-template.csv';

function startServer(dataDir, redisUrl) {
  const next = path.join(root, 'node_modules/next/dist/bin/next');
  // Run Next directly so the process we stop owns the listening socket on every platform.
  const child = spawn(process.execPath, [next, 'start', app, '--hostname', '127.0.0.1', '--port', '0'], {
    cwd: root, windowsHide: true, stdio: ['ignore', 'pipe', 'pipe'],
    env: {...process.env, NEXT_TELEMETRY_DISABLED: '1', STOCKPILOT_PYTHON: python, STOCKPILOT_DATA_DIR: dataDir,
      STOCKPILOT_REDIS_URL: redisUrl},
  });
  const closed = new Promise(resolve => child.once('close', resolve));
  const address = new Promise((resolve, reject) => {
    let output = '';
    const timer = setTimeout(() => reject(new Error('Next failed to start. ' + output)), 30_000);
    const collect = chunk => {
      output = (output + chunk.toString()).slice(-8000);
      const match = /http:\/\/127\.0\.0\.1:\d+(?=\s|\x1b)/.exec(output);
      if (match) { clearTimeout(timer); resolve(match[0]); }
    };
    child.stdout.on('data', collect);
    child.stderr.on('data', collect);
    child.once('error', err => { clearTimeout(timer); reject(err); });
    child.once('close', () => { clearTimeout(timer); reject(new Error('Next exited. ' + output)); });
  });
  return {address, async stop() {
    if (child.exitCode === null && child.signalCode === null) child.kill('SIGTERM');
    const force = setTimeout(() => child.kill('SIGKILL'), 3_000);
    try { await closed; } finally { clearTimeout(force); }
  }};
}

async function getResponse(url, options) {
  const response = await fetch(url, {signal: AbortSignal.timeout(95_000), ...options});
  if (!response.ok) assert.fail('HTTP ' + response.status + ' for ' + url + ': ' + (await response.text()).slice(0, 500));
  return response;
}

async function checkWorkspacePages(origin) {
  for (const legacy of ['/', '/simulation', '/retail', '/transfer', '/dashboard']) {
    const response = await fetch(origin + legacy, {redirect: 'manual'});
    assert.equal(response.status, 308, legacy);
    assert.equal(new URL(response.headers.get('location'), origin).href, origin + (legacy === '/transfer' ? '/transfers' : '/forecast'));
  }
  const pages = [
    ['/forecast', '/forecast', 'forecast-empty'],
    ['/transfers', '/transfers', 'transfers-page'],
    ['/evaluation', '/evaluation', 'evaluation-page'],
    ['/import', '/import', 'forecast-upload'],
    ['/projects', '/projects', 'projects-page'],
  ];
  for (const [url, activeLink, contentId] of pages) {
    const html = await (await getResponse(origin + url)).text();
    assert.ok(html.includes(`id="${contentId}"`), `${url} must serve its own page content`);
    if (url === '/import') assert.ok(html.includes('href="/weekly-sales-template.csv"'));
    const navigation = html.match(/<nav\b[^>]*id="workspace-navigation"[^>]*>([\s\S]*?)<\/nav>/)?.[1];
    assert.ok(navigation, `${url} must serve the workspace navigation`);
    const links = navigation.match(/<a\s+[^>]*>/g) ?? [];
    for (const [href] of pages) {
      const link = links.find(tag => tag.includes(`href="${href}"`));
      assert.ok(link, `${url} must link to ${href}`);
      assert.equal(link.includes('aria-current="page"'), href === activeLink);
    }
    if (activeLink === '/forecast') {
      assert.ok(!html.includes('id="forecast-upload"'), 'The import form belongs on the import page');
      assert.ok(!html.includes('data-series="xgboost"'), 'A new workspace starts with an empty chart');
    }
  }
}

test('production workspace trains from the public template and restores its forecast after restart', async () => {
  const dataDir = await mkdtemp(path.join(os.tmpdir(), 'stockpilot-release-'));
  const brokerDirectory = path.join(dataDir, '.broker');
  let broker = await startLocalBroker({directory: brokerDirectory});
  let server = startServer(dataDir, broker.url);
  try {
    const origin = await server.address;
    await checkWorkspacePages(origin);
    const routes = JSON.parse(await readFile(path.join(app, '.next/routes-manifest.json'), 'utf8'));
    const pages = [...routes.staticRoutes, ...routes.dynamicRoutes].map(r => r.page).filter(p => !p.startsWith('/_'));
    assert.deepEqual(pages.sort(), ['/', '/api/forecast', '/evaluation', '/forecast', '/import', '/projects', '/transfers']);
    assert.deepEqual(await readdir(path.join(app, 'public')), [template]);
    const capabilities = await (await getResponse(origin + '/api/forecast?capabilities=1')).json();
    assert.ok(Array.isArray(capabilities.peerModels));
    assert.deepEqual(capabilities.peerModels, []);
    const empty = await (await getResponse(origin + '/api/forecast')).json();
    assert.deepEqual(empty, {projects: [], projectId: null, result: null, savedAt: null});
    const csv = await (await getResponse(origin + '/' + template)).text();
    const trained = await (await getResponse(origin + '/api/forecast', {
      method: 'POST', headers: {'Content-Type': 'application/json', Origin: origin}, body: JSON.stringify({csv}),
    })).json();
    assert.equal(trained.result.training.parameters.n_estimators, 40);
    assert.deepEqual(trained.result.models.map(m => m.id), ['xgboost']);
    assert.equal(trained.result.scores[0].count, 4);
    assert.ok(Number.isFinite(trained.result.scores[0].mae.xgboost));
    assert.match(trained.projectId, /^[a-f0-9]{64}$/);
    const parameters = {n_estimators: 32, max_depth: 3, learning_rate: 0.12};
    const tuned = await (await getResponse(origin + '/api/forecast', {
      method: 'POST', headers: {'Content-Type': 'application/json', Origin: origin},
      body: JSON.stringify({csv, parameters}),
    })).json();
    assert.notEqual(tuned.projectId, trained.projectId);
    for (const [name, value] of Object.entries(parameters)) {
      assert.equal(tuned.result.training.parameters[name], value);
    }
    const project = path.join(dataDir, tuned.projectId);
    assert.deepEqual((await readdir(project)).sort(), ['forecast.json', 'history.csv', 'model.ubj', 'project.json']);
    const rerun = await (await getResponse(origin + '/api/forecast', {
      method: 'POST', headers: {'Content-Type': 'application/json', Origin: origin},
      body: JSON.stringify({projectId: tuned.projectId, peers: []}),
    })).json();
    assert.equal(rerun.projectId, tuned.projectId);
    assert.deepEqual(rerun.result, tuned.result);
    const future = await (await getResponse(origin + '/api/forecast', {
      method: 'POST', headers: {'Content-Type': 'application/json', Origin: origin},
      body: JSON.stringify({projectId: tuned.projectId, forecastStart: '2025-03-10', forecastEnd: '2025-03-17'}),
    })).json();
    assert.deepEqual(future.result.weeks.map(w => w.week), ['2025-03-10', '2025-03-17']);
    assert.ok(future.result.weeks.every(w => w.stores.every(row =>
      row.actual === null && Number.isFinite(row.forecasts.xgboost))));

    await server.stop();
    await broker.stop();
    broker = await startLocalBroker({directory: brokerDirectory});
    server = startServer(dataDir, broker.url);
    const endpoint = (await server.address) + '/api/forecast';
    const queue = await (await getResponse(endpoint + '?queue=1')).json();
    assert.equal(queue.jobs.filter(job => job.status === 'completed').length, 4);
    const restored = await (await getResponse(endpoint)).json();
    assert.equal(restored.projectId, future.projectId);
    assert.deepEqual(restored.result, future.result);
    const original = await (await getResponse(endpoint + '?id=' + trained.projectId)).json();
    assert.deepEqual(original.result, trained.result);
    const replay = spawnSync(python, ['-B', '-c', [
      'import json, sys',
      'from pathlib import Path',
      'from xgboost import XGBRegressor',
      'from stockpilot_local.worker import parse_csv',
      'from stockpilot_local.xgb import predict_next',
      'folder = Path(sys.argv[1])',
      'groups, _ = parse_csv((folder / "history.csv").read_text(encoding="utf-8"))',
      'tree = XGBRegressor()',
      'tree.load_model(folder / "model.ubj")',
      'print(json.dumps(predict_next(tree, next(iter(groups.values())))))',
    ].join('\n'), project], {cwd: root, windowsHide: true, encoding: 'utf8', timeout: 90_000});
    if (replay.error) throw replay.error;
    assert.equal(replay.status, 0, replay.stderr);
    assert.deepEqual(JSON.parse(replay.stdout), tuned.result.next);
  } finally {
    await server.stop();
    await broker.stop();
    await rm(dataDir, {recursive: true, force: true, maxRetries: 4, retryDelay: 100});
  }
});
