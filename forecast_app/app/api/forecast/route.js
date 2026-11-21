import { spawn } from 'node:child_process';
import { existsSync } from 'node:fs';
import { dirname, join } from 'node:path';

export const runtime = 'nodejs';
export const dynamic = 'force-dynamic';

const mib = 1024 * 1024;
const maxRequestBytes = 2 * mib + 4096;
const trainingTimeout = 90_000;
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
  if (typeof payload?.csv !== 'string') throw new RequestError(400, 'Missing CSV upload.');
  if (Buffer.byteLength(payload.csv) > mib) throw new RequestError(413, 'The CSV exceeds the 1 MiB upload limit.');
  return {csv: payload.csv, item: payload.item};
}

function runForecast(payload, signal) {
  const cwd = process.cwd();
  const root = existsSync(join(cwd, 'stockpilot_local', 'worker.py')) ? cwd : dirname(cwd);
  const windows = process.platform === 'win32';
  const localPython = join(root, '.venv', windows ? 'Scripts/python.exe' : 'bin/python');
  const python = process.env.STOCKPILOT_PYTHON || (existsSync(localPython) ? localPython : windows ? 'python' : 'python3');
  return new Promise((resolve, reject) => {
    const child = spawn(python, ['-B', '-m', 'stockpilot_local.worker'], {
      cwd: root, windowsHide: true, stdio: ['pipe', 'pipe', 'ignore'],
      env: {...process.env, PYTHONIOENCODING: 'utf-8'},
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
      if (size > 8 * mib) stop(new RequestError(422, 'The forecast response is too large. Try fewer stores.'));
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
  return respond(request, () => runForecast({op: 'read', id: new URL(request.url).searchParams.get('id')}, request.signal));
}

export function POST(request) {
  return respond(request, async () => {
    const payload = await readUpload(request);
    if (training) throw new RequestError(429, 'A forecast is already running. Retry when it finishes.');
    training = true;
    try {
      return await runForecast({...payload, op: 'train'}, request.signal);
    } finally {
      training = false;
    }
  });
}
