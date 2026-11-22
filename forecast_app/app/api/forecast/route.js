import {enqueue, forecastQueue, getJob, listJobs, waitForJob} from '../../../server/forecast-queue.mjs';
import {RequestError, runForecast} from '../../../server/forecast-worker.mjs';

export const runtime = 'nodejs';
export const dynamic = 'force-dynamic';

const mib = 1024 * 1024;
const maxRequestBytes = 2 * mib + 4096;
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
  const json = (data, status = 200) => Response.json(data, {status, headers: {'Cache-Control': 'no-store'}});
  try {
    requireLocalOrigin(request);
    return await action(json);
  } catch (error) {
    if (error instanceof RequestError) return json({error: error.message}, error.status);
    return json({error: 'Unable to access the local forecast service.'}, 503);
  }
}

export function GET(request) {
  return respond(request, async json => {
    const query = new URL(request.url).searchParams;
    if (query.has('job')) {
      const options = {result: query.get('result') === '1', activate: query.get('activate') === '1'};
      return json(await getJob(await forecastQueue(), query.get('job'), options));
    }
    if (query.get('queue') === '1') return json(await listJobs(await forecastQueue()));
    const payload = query.get('capabilities') === '1' ? {op: 'capabilities'} : {op: 'read', id: query.get('id')};
    return json(await runForecast(payload, {signal: request.signal}));
  });
}

export function POST(request) {
  return respond(request, async json => {
    const payload = await readUpload(request);
    const inspected = await runForecast({...payload, op: 'inspect', action: payload.op}, {signal: request.signal});
    if (inspected.selectionRequired) return json(inspected);
    const asyncResult = (request.headers.get('prefer') || '').split(',').some(v => v.trim().toLowerCase() === 'respond-async');
    const service = await forecastQueue();
    const job = await enqueue(service, {...payload, item: inspected.item, activate: !asyncResult}, inspected.item);
    if (asyncResult) return json({job}, 202);
    return json(await waitForJob(service, job.id, request.signal));
  });
}
