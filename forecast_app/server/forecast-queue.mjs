import {createHash, randomUUID} from 'node:crypto';
import {mkdir} from 'node:fs/promises';
import {join} from 'node:path';
import {setTimeout as delay} from 'node:timers/promises';
import {Queue, Worker} from 'bullmq';
import Redis from 'ioredis';
import {getRedisConnection, forecastDataDir} from './redis-connection.mjs';
import {jobFiles, validJobId} from './forecast-job-files.mjs';
import {RequestError, runForecast, workerSettings} from './forecast-worker.mjs';

const history = 24;
const backlog = 64;
const openQueues = globalThis[Symbol.for('stockpilot.forecast.queues')] ??= new Map();
const iso = timestamp => timestamp ? new Date(timestamp).toISOString() : null;

function modelsFor(job, status) {
  return job.data.models.map(id => {
    const stage = job.progress?.models?.find(model => model.id === id);
    if (status === 'failed' && (!stage || stage.status === 'queued')) return {id, status: 'skipped'};
    if (status === 'failed' && stage?.status === 'running') return {id, status: 'failed'};
    return stage ?? {id, status: 'queued'};
  });
}

function summary(job, state) {
  // A job can move from a waiting/active index to a terminal state while BullMQ is fetching its fields.
  if (job.finishedOn && (job.returnvalue?.projectId || job.failedReason)) state = job.returnvalue?.projectId ? 'completed' : 'failed';
  const status = ({waiting:'queued', active:'running', completed:'completed', failed:'failed'})[state] ?? 'queued';
  return {id:job.id, item:job.data.item, status, models:modelsFor(job, status),
    createdAt:iso(job.timestamp), startedAt:iso(job.processedOn), finishedAt:iso(job.finishedOn),
    forecastStart:job.data.forecastStart ?? null, forecastEnd:job.data.forecastEnd ?? null,
    projectId:job.returnvalue?.projectId ?? null, error:status === 'failed' ? job.failedReason : null};
}

async function processJob(job, files, settings) {
  // A restarted worker may reclaim the job after the forecast was saved and before BullMQ acknowledged it.
  const existing = await files.result(job.id);
  if (existing) return completeJob(job, files, existing);
  const models = job.data.models.map(id => ({id, status:'queued'}));
  const onModel = async event => {
    const model = models.find(m => m.id === event.model);
    if (!model || !['running','completed','failed'].includes(event.status)) return;
    Object.assign(model, {status:event.status}, event.error ? {error:event.error} : {});
    await job.updateProgress({models});
  };
  try {
    const input = await files.input(job.id);
    if (!input) throw new RequestError(500, 'The saved input for this forecast job could not be found.');
    const snapshot = await runForecast({...input, progress:true}, {settings, onModel});
    await files.saveResult(job.id, snapshot);
    return await completeJob(job, files, snapshot);
  } catch (error) {
    await job.updateProgress({models, errorStatus:error.status || 500});
    // Retain input until BullMQ records the failure, so stalled workers can recover it.
    throw new Error(error instanceof RequestError ? error.message : 'The local forecast job could not finish.');
  }
}

async function completeJob(job, files, snapshot) {
  const produced = new Set(snapshot.result.models.map(model => model.id));
  const warnings = new Map(snapshot.result.modelWarnings?.map(warning => [warning.id, warning.message]));
  const models = job.data.models.map(id => {
    if (warnings.has(id)) return {id, status:'failed', error:warnings.get(id)};
    return {id, status:produced.has(id) ? 'completed' : 'skipped'};
  });
  await job.updateProgress({models});
  await files.forgetInput(job.id);
  return {projectId:snapshot.projectId};
}

async function connectProducer(options) {
  // Return a 503 promptly during startup, then reconnect an established queue if its broker restarts.
  let connected = false;
  const client = new Redis({...options, lazyConnect:true, enableOfflineQueue:false, connectTimeout:1500,
    maxRetriesPerRequest:1, retryStrategy:times => connected ? Math.min(200 * times, 2000) : null});
  client.on('error', () => {}); // Connection and command failures propagate to callers.
  try { await client.connect(); connected = true; return client; }
  catch (error) { client.disconnect(); throw error; }
}

async function createService(name, directory, settings) {
  const connection = await getRedisConnection();
  await mkdir(directory, {recursive:true, mode:0o700});
  const files = jobFiles(directory);
  const client = await connectProducer(connection);
  const queue = new Queue(name, {connection:client,
    defaultJobOptions:{removeOnComplete:{count:history}, removeOnFail:{count:history}}});
  // Bound heavy CPU/model work across all Next processes serving this data directory.
  try { await queue.setGlobalConcurrency(1); }
  catch (error) { await queue.close(); client.disconnect(); throw error; }
  const worker = new Worker(name, job => processJob(job, files, settings), {
    connection:{...connection, maxRetriesPerRequest:null}, concurrency:1,
  });
  const logError = () => console.error('StockPilot could not contact the local forecast queue.');
  queue.on('error', logError);
  worker.on('error', logError);
  let pruning;
  const prune = () => {
    pruning ??= files.prune(queue).catch(logError).finally(() => { pruning = null; });
  };
  worker.on('completed', prune);
  worker.on('failed', job => {
    if (job) files.forgetInput(job.id).catch(logError);
    prune();
  });
  prune();
  async function close() {
    await worker.close();
    await pruning;
    await queue.close();
    client.disconnect();
  }
  return {queue, worker, files, close};
}

export function forecastQueue() {
  const settings = workerSettings();
  const data = forecastDataDir();
  const location = JSON.stringify([data, settings.root]);
  const key = createHash('sha256').update(process.platform === 'win32' ? location.toLowerCase() : location).digest('hex').slice(0,24);
  if (!openQueues.has(key)) {
    const service = createService('stockpilot-forecasts-' + key, join(data, '.jobs', key), settings)
      .catch(() => { openQueues.delete(key); throw new RequestError(503, 'The local forecast queue is unavailable. Start StockPilot with its local broker.'); });
    openQueues.set(key, service);
  }
  return openQueues.get(key);
}

export async function enqueue(service, input, item) {
  const {queue, files} = service;
  if (await queue.getWaitingCount() >= backlog) throw new RequestError(429, 'The forecast queue is full. Try again after a run finishes.');
  const id = randomUUID();
  await files.putInput(id, input);
  const data = {item, models:['xgboost', ...(input.peers || [])],
    forecastStart:input.forecastStart, forecastEnd:input.forecastEnd};
  // A network failure during add has an ambiguous outcome. Leave the input for recovery or pruning.
  const job = await queue.add('forecast', data, {jobId:id});
  return summary(job, 'waiting');
}

export async function listJobs({queue}) {
  const groups = await Promise.all([
    queue.getWaiting(0, backlog - 1), queue.getActive(0, 0),
    queue.getCompleted(0, history - 1), queue.getFailed(0, history - 1),
  ]);
  const states = ['waiting','active','completed','failed'];
  const rows = new Map();
  groups.forEach((jobs, group) => {
    for (const job of jobs) rows.set(job.id, summary(job, states[group]));
  });
  const all = [...rows.values()];
  const ended = all.filter(job => job.finishedAt).sort((a,b) => b.finishedAt.localeCompare(a.finishedAt));
  return {jobs:[...all.filter(job => job.status === 'running'), ...all.filter(job => job.status === 'queued'),
    ...ended.slice(0,history)]};
}

export async function getJob({queue, files}, id, {result, activate} = {}) {
  if (!validJobId(id)) throw new RequestError(404, 'The forecast job was not found.');
  const state = await queue.getJobState(id);
  const job = await queue.getJob(id);
  if (!job) throw new RequestError(404, 'This job is outside the recent forecast queue.');
  const response = {job:summary(job, state)};
  if (result && response.job.status === 'completed') {
    const snapshot = await files.result(id);
    if (!snapshot) throw new RequestError(404, 'The saved result for this forecast job is unavailable.');
    if (!Object.hasOwn(snapshot.result.historyRange ?? {}, 'recommendedStart')) {
      const restored = await runForecast({op:'read', id:snapshot.projectId, activate:false});
      snapshot.result.historyRange = restored.result.historyRange;
    }
    if (activate) {
      const current = await runForecast({op:'activate', id:snapshot.projectId, comparisonResult:snapshot.result});
      snapshot.projects = current.projects;
    }
    response.snapshot = snapshot;
  }
  return response;
}

export async function waitForJob(service, id, signal) {
  // Disconnect abandons only this compatibility response. BullMQ owns the accepted run.
  while (!signal?.aborted) {
    const {job, snapshot} = await getJob(service, id, {result:true});
    if (snapshot) return snapshot;
    if (job.status === 'failed') {
      const failed = await service.queue.getJob(id);
      throw new RequestError(failed?.progress?.errorStatus || 500, job.error);
    }
    await delay(120);
  }
  throw new RequestError(408, 'The forecast response was cancelled.');
}

export async function closeForecastQueues() {
  const services = [...openQueues.values()];
  openQueues.clear();
  for (const service of services) {
    await (await service).close();
  }
}
