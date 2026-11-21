import assert from 'node:assert/strict';
import { spawn, spawnSync } from 'node:child_process';
import { mkdtemp, readFile, readdir, rm } from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import test from 'node:test';
import { fileURLToPath } from 'node:url';

const root = fileURLToPath(new URL('../', import.meta.url));
const app = path.join(root, 'forecast_app');
const python = process.env.STOCKPILOT_PYTHON ||
  path.join(root, '.venv', process.platform === 'win32' ? 'Scripts/python.exe' : 'bin/python');
const template = 'weekly-sales-template.csv';

function startServer(dataDir) {
  const next = path.join(root, 'node_modules/next/dist/bin/next');
  // Run Next directly so the process we stop owns the listening socket on every platform.
  const child = spawn(process.execPath, [next, 'start', app, '--hostname', '127.0.0.1', '--port', '0'], {
    cwd: root, windowsHide: true, stdio: ['ignore', 'pipe', 'pipe'],
    env: {...process.env, NEXT_TELEMETRY_DISABLED: '1', STOCKPILOT_PYTHON: python, STOCKPILOT_DATA_DIR: dataDir},
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
  const pages = [
    ['/', '/forecast', 'forecast-empty'],
    ['/forecast', '/forecast', 'forecast-empty'],
    ['/evaluation', '/evaluation', 'evaluation-page'],
    ['/import', '/import', 'forecast-upload'],
    ['/projects', '/projects', 'projects-page'],
  ];
  for (const [url, activeLink, contentId] of pages) {
    const html = await (await getResponse(origin + url)).text();
    assert.ok(html.includes(`id="${contentId}"`), `${url} must serve its own page content`);
    const navigation = html.match(/<nav\b[^>]*id="workspace-navigation"[^>]*>([\s\S]*?)<\/nav>/)?.[1];
    assert.ok(navigation, `${url} must serve the workspace navigation`);
    const links = navigation.match(/<a\s+[^>]*>/g) ?? [];
    for (const href of ['/forecast', '/evaluation', '/import', '/projects']) {
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
  let server = startServer(dataDir);
  try {
    const origin = await server.address;
    await checkWorkspacePages(origin);
    const routes = JSON.parse(await readFile(path.join(app, '.next/routes-manifest.json'), 'utf8'));
    const pages = [...routes.staticRoutes, ...routes.dynamicRoutes].map(r => r.page).filter(p => !p.startsWith('/_'));
    assert.deepEqual(pages.sort(), ['/', '/api/forecast', '/evaluation', '/forecast', '/import', '/projects']);
    assert.deepEqual(await readdir(path.join(app, 'public')), [template]);
    const empty = await (await getResponse(origin + '/api/forecast')).json();
    assert.deepEqual(empty, {projects: [], projectId: null, result: null, savedAt: null});
    const csv = await (await getResponse(origin + '/' + template)).text();
    const trained = await (await getResponse(origin + '/api/forecast', {
      method: 'POST', headers: {'Content-Type': 'application/json', Origin: origin}, body: JSON.stringify({csv}),
    })).json();
    assert.deepEqual(trained.result.models.map(m => m.id), ['xgboost']);
    assert.equal(trained.result.scores[0].count, 4);
    assert.ok(Number.isFinite(trained.result.scores[0].mae.xgboost));
    assert.match(trained.projectId, /^[a-f0-9]{64}$/);
    const project = path.join(dataDir, trained.projectId);
    assert.deepEqual((await readdir(project)).sort(), ['forecast.json', 'history.csv', 'model.ubj', 'project.json']);

    await server.stop();
    server = startServer(dataDir);
    const restored = await (await getResponse((await server.address) + '/api/forecast')).json();
    assert.equal(restored.projectId, trained.projectId);
    assert.deepEqual(restored.result, trained.result);
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
    assert.deepEqual(JSON.parse(replay.stdout), restored.result.next);
  } finally {
    await server.stop();
    await rm(dataDir, {recursive: true, force: true, maxRetries: 4, retryDelay: 100});
  }
});
