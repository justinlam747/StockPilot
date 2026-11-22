import {spawn} from 'node:child_process';
import {existsSync} from 'node:fs';
import {dirname, join} from 'node:path';
import {createInterface} from 'node:readline';

export class RequestError extends Error {
  constructor(status, message) {
    super(message);
    this.status = status;
  }
}

export function workerSettings() {
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

function reportProgress(stderr, onModel) {
  let pending = Promise.resolve(), failure;
  const prefix = 'STOCKPILOT_EVENT ';
  createInterface({input: stderr}).on('line', line => {
    if (!line.startsWith(prefix)) return;
    try {
      const event = JSON.parse(line.slice(prefix.length));
      pending = pending.then(() => onModel(event)).catch(error => { failure = error; });
    } catch { /* Unrelated interpreter diagnostics never enter the forecast result. */ }
  });
  return async () => { await pending; if (failure) throw failure; };
}

export function runForecast(payload, {signal, onModel, settings = workerSettings()} = {}) {
  const {root, python, module, env} = settings;
  return new Promise((resolve, reject) => {
    const child = spawn(/* turbopackIgnore: true */ python, ['-B', '-m', module], {
      cwd: root, env, windowsHide: true, stdio: ['pipe', 'pipe', onModel ? 'pipe' : 'ignore'],
    });
    let failure;
    const stop = error => { failure = error; child.kill('SIGKILL'); };
    const abort = () => stop(new RequestError(408, 'The forecast request was cancelled.'));
    const timer = setTimeout(() => stop(new RequestError(504, 'The local forecast worker timed out.')),
      payload.peers?.length ? 300_000 : 90_000);
    signal?.addEventListener('abort', abort, {once: true});
    if (signal?.aborted) abort();
    const finishEvents = onModel && reportProgress(child.stderr, onModel);
    const chunks = [];
    let size = 0;
    child.stdout.on('data', chunk => {
      size += chunk.length;
      if (size > 16 * 1024 * 1024) stop(new RequestError(422, 'The forecast response is too large. Try fewer stores.'));
      else chunks.push(chunk);
    });
    child.stdin.on('error', () => {});
    child.on('error', () => { failure = new RequestError(503, 'The local Python forecast worker could not start.'); });
    child.on('close', async code => {
      clearTimeout(timer);
      signal?.removeEventListener('abort', abort);
      if (failure) return reject(failure);
      if (code !== 0) return reject(new RequestError(500, 'The local forecast worker could not complete the request.'));
      try {
        if (finishEvents) await finishEvents();
        const data = JSON.parse(Buffer.concat(chunks).toString('utf8'));
        if (data.error) throw new RequestError(data.status || 422, data.error);
        resolve(data);
      } catch (error) {
        reject(error instanceof RequestError ? error : new RequestError(500, 'The local worker returned an incomplete forecast.'));
      }
    });
    child.stdin.end(JSON.stringify(payload), 'utf8');
  });
}
