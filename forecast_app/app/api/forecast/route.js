import { spawn } from 'node:child_process';
import { existsSync } from 'node:fs';
import { dirname, join } from 'node:path';

export const runtime = 'nodejs';
export const dynamic = 'force-dynamic';

const mib = 1024 * 1024;
const maxRequestBytes = 2 * mib + 4096;
let training = false;

class RequestError extends Error {
  constructor(status, message) {
    super(message);
    this.status = status;
  }
}

async function readUpload(request) {
  if (request.headers.get('content-type')?.split(';')[0].trim() !== 'application/json') {
    throw new RequestError(415, 'Send a JSON request containing the CSV.');
  }
  if (!request.body) throw new RequestError(400, 'Missing CSV upload.');
  const reader = request.body.getReader();
  const chunks = [];
  let bytes = 0;
  while (true) {
    const {done, value} = await reader.read();
    if (done) break;
    bytes += value.byteLength;
    if (bytes > maxRequestBytes) {
      await reader.cancel();
      throw new RequestError(413, 'The CSV exceeds the 1 MiB upload limit.');
    }
    chunks.push(value);
  }
  let payload;
  try {
    payload = JSON.parse(new TextDecoder('utf-8', {fatal: true}).decode(Buffer.concat(chunks)));
  } catch {
    throw new RequestError(400, 'The upload must be valid UTF-8 JSON.');
  }
  const {projectId, peers, forecastStart, forecastEnd} = payload ?? {};
  if (projectId !== undefined) {
    if (payload.csv !== undefined) throw new RequestError(400, 'Choose a saved project or upload a CSV.');
    return {op: 'rerun', projectId, peers, forecastStart, forecastEnd};
  }
  if (typeof payload?.csv !== 'string') throw new RequestError(400, 'Missing CSV upload.');
  if (Buffer.byteLength(payload.csv) > mib) throw new RequestError(413, 'The CSV exceeds the 1 MiB upload limit.');
  return {op: 'train', csv: payload.csv, item: payload.item, parameters: payload.parameters, peers, forecastStart, forecastEnd};
}

function workerSettings() {
  const cwd = process.cwd();
  const root = existsSync(join(cwd, 'stockpilot_local', 'worker.py')) ? cwd : dirname(cwd);
  const windows = process.platform === 'win32';
  const interpreter = windows ? 'Scripts/python.exe' : 'bin/python';
  const localPython = join(root, '.venv', interpreter);
  const env = {...process.env, PYTHONIOENCODING: 'utf-8'};
  const researchPython = env.STOCKPILOT_RESEARCH_PYTHON || join(root, '.venv-dashboard', interpreter);
  if (env.STOCKPILOT_DISABLE_PEERS !== '1' && existsSync(/* turbopackIgnore: true */ researchPython) &&
      existsSync(join(root, 'local_dashboard', 'workspace_comparison.py'))) {
    env.HF_HUB_OFFLINE = '1';
    env.TRANSFORMERS_OFFLINE = '1';
    const cache = env.BB_THREAD_STORAGE && join(env.BB_THREAD_STORAGE, 'chronos-cache');
    if (!env.HF_HOME && !env.HF_HUB_CACHE && cache && existsSync(join(cache, 'hub'))) env.HF_HOME = cache;
    return {root, python: researchPython, module: 'local_dashboard.workspace_comparison', env};
  }
  const python = env.STOCKPILOT_PYTHON || (existsSync(localPython) ? localPython : windows ? 'python' : 'python3');
  return {root, python, module: 'stockpilot_local.worker', env};
}

function runForecast(payload, signal) {
  const {root, python, module, env} = workerSettings();
  const trainingTimeout = payload.peers?.length ? 300_000 : 90_000;
  return new Promise((resolve, reject) => {
    const child = spawn(/* turbopackIgnore: true */ python, ['-B', '-m', module], {
      cwd: root, env, windowsHide: true, stdio: ['pipe', 'pipe', 'ignore'],
    });
    let failure;
    const stop = error => { failure = error; child.kill('SIGKILL'); };
    const abort = () => stop(new RequestError(408, 'The forecast request was cancelled.'));
    const timer = setTimeout(() => stop(new RequestError(504, 'The local forecast worker timed out.')), trainingTimeout);
    signal.addEventListener('abort', abort, {once: true});
    if (signal.aborted) abort();
    const chunks = [];
    let size = 0;
    child.stdout.on('data', chunk => {
      size += chunk.length;
      if (size > 16 * mib) stop(new RequestError(422, 'The forecast response is too large. Try fewer stores.'));
      else chunks.push(chunk);
    });
    child.stdin.on('error', () => {}); // Early interpreter exits close stdin; close handles the failure below.
    child.on('error', () => { failure = new RequestError(503, 'The local Python forecast worker could not start.'); });
    child.on('close', code => {
      clearTimeout(timer);
      signal.removeEventListener('abort', abort);
      if (failure) return reject(failure);
      if (code !== 0) return reject(new RequestError(500, 'The local forecast worker could not complete the request.'));
      try { resolve(JSON.parse(Buffer.concat(chunks).toString('utf8'))); }
      catch { reject(new RequestError(500, 'The local worker returned an incomplete forecast.')); }
    });
    child.stdin.end(JSON.stringify(payload), 'utf8');
  });
}

function requireLocalOrigin(request) {
  const host = request.headers.get('host')?.toLowerCase() || '';
  const origin = request.headers.get('origin');
  if (!/^(?:localhost|127\.0\.0\.1|\[::1\])(?::\d+)?$/.test(host) ||
      (origin && (!URL.canParse(origin) || new URL(origin).host.toLowerCase() !== host)) ||
      request.headers.get('sec-fetch-site') === 'cross-site') {
    throw new RequestError(403, 'Open StockPilot on localhost to use your local forecasts.');
  }
}

async function respond(request, action) {
  const json = (data, status) => Response.json(data, {status, headers: {'Cache-Control': 'no-store'}});
  try {
    requireLocalOrigin(request);
    const result = await action();
    if (result.error) throw new RequestError(result.status || 422, result.error);
    return json(result, 200);
  } catch (error) {
    return json({error: error instanceof RequestError ? error.message : 'Unable to read the local forecast request.'},
      error instanceof RequestError ? error.status : 500);
  }
}

export function GET(request) {
  const query = new URL(request.url).searchParams;
  const payload = query.get('capabilities') === '1' ? {op: 'capabilities'} : {op: 'read', id: query.get('id')};
  return respond(request, () => runForecast(payload, request.signal));
}

export function POST(request) {
  return respond(request, async () => {
    const payload = await readUpload(request);
    if (training) throw new RequestError(429, 'A forecast is already running. Retry when it finishes.');
    training = true;
    try {
      return await runForecast(payload, request.signal);
    } finally {
      training = false;
    }
  });
}
