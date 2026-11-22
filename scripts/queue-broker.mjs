import {spawn, spawnSync} from 'node:child_process';
import {createHash, randomBytes, randomUUID} from 'node:crypto';
import {link, mkdir, readFile, realpath, unlink, writeFile} from 'node:fs/promises';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {setTimeout as delay} from 'node:timers/promises';
import Redis from 'ioredis';
import {forecastDataDir} from '../forecast_app/server/redis-connection.mjs';

const root = fileURLToPath(new URL('../', import.meta.url));
const portable = path.join(root, '.venv', 'stockpilot-redis', '8.10.3', 'redis-server.exe');
const launcherPrefix = 'stockpilot-launcher-';
const lifecycleLock = 'stockpilot:broker:lifecycle';
const loading = Symbol('broker loading');

function compatible(version) {
  const [major, minor] = version.split('.').map(Number);
  return major > 6 || (major === 6 && minor >= 2);
}

function findServer() {
  const configured = process.env.STOCKPILOT_REDIS_SERVER;
  const candidates = configured ? [configured] :
    process.platform === 'win32' ? [portable, 'valkey-server', 'redis-server'] : ['valkey-server', 'redis-server'];
  for (const executable of candidates) {
    const version = spawnSync(executable, ['--version'], {encoding:'utf8', timeout:5000, windowsHide:true});
    const match = /\bv=(\d+\.\d+)/.exec(version.stdout || '');
    if (match && compatible(match[1])) return executable;
  }
  throw new Error(process.platform === 'win32' ? 'Run npm run setup to install the local Redis queue server.' :
    'Install valkey-server or Redis 6.2+ on this computer, or set STOCKPILOT_REDIS_URL to your local Redis server.');
}

async function brokerPassword(directory) {
  const file = path.join(directory, 'broker.key');
  const read = async () => {
    const password = await readFile(file, 'utf8');
    if (!/^[0-9a-f]{64}$/.test(password)) throw new Error('The local queue broker key is invalid.');
    return password;
  };
  try { return await read(); } catch (error) { if (error.code !== 'ENOENT') throw error; }
  // Publish an already complete secret without replacing one written by a concurrent launcher.
  const temp = file + '.' + randomUUID();
  await writeFile(temp, randomBytes(32).toString('hex'), {mode:0o600, flag:'wx'});
  try { await link(temp, file); } catch (error) { if (error.code !== 'EEXIST') throw error; }
  finally { await unlink(temp); }
  return read();
}

function controlClient({host, port}) {
  // No automatic AUTH fallback, client metadata writes, reconnection or command replay.
  const client = new Redis({host, port, lazyConnect:true, enableOfflineQueue:false, enableReadyCheck:false,
    disableClientInfo:true, connectTimeout:1000, commandTimeout:2500, retryStrategy:() => null});
  client.on('error', () => {});
  return client;
}

export async function verifyExternalBroker(options) {
  const client = controlClient(options);
  let version;
  try {
    await client.connect();
    if (options.username) await client.auth(options.username, options.password ?? '');
    else if (options.password) await client.auth(options.password);
    if (options.db) await client.select(options.db);
    const info = await client.info('server');
    version = /^(?:valkey_version|redis_version):([\d.]+)/m.exec(info)?.[1];
  } catch {
    throw new Error('Cannot connect to the configured local Redis server at ' + options.host + ':' + options.port +
      '. Check the server, database and credentials.');
  } finally { client.disconnect(); }
  if (!version || !compatible(version)) {
    throw new Error('The local queue requires Redis 6.2+ or Valkey. Port ' + options.port +
      ' reported ' + (version ?? 'an unknown version') + '.');
  }
}

async function lock(client, owner, serverId) {
  const deadline = Date.now() + 12000;
  do {
    if (await client.set(lifecycleLock + ':' + serverId, owner, 'PX', 10000, 'NX') === 'OK') return;
    await delay(50);
  } while (Date.now() < deadline);
  throw new Error('The local queue broker is busy starting or stopping another launcher.');
}

async function unlock(client, owner, serverId) {
  await client.eval("if redis.call('GET',KEYS[1]) == ARGV[1] then return redis.call('DEL',KEYS[1]) end", 1, lifecycleLock + ':' + serverId, owner);
}

async function runId(client) {
  return /^run_id:([a-f0-9]{40})\r?$/m.exec(await client.info('server'))?.[1];
}

async function release(client, owner, expected) {
  // Each control socket loses its lease automatically if its launcher dies.
  try {
    await lock(client, owner, expected);
    await client.client('SETNAME', '');
    const list = await client.client('LIST');
    if (list.split(/\s+/).some(field => field.startsWith('name=' + launcherPrefix))) {
      await unlock(client, owner, expected);
    } else if (await runId(client) === expected) {
      // This is the same authenticated, non-reconnecting socket that claimed the lease.
      try { await client.call('SHUTDOWN', 'NOSAVE'); }
      catch (error) { if (!/connection is closed/i.test(error.message)) throw error; }
    }
  } finally { client.disconnect(); }
}

async function claim(host, port, password) {
  const client = controlClient({host, port});
  try { await client.connect(); } catch { client.disconnect(); return null; }
  try {
    // PING alone would also succeed on an unrelated server that doesn't require a password.
    if (await client.auth(password) !== 'OK') throw new Error('Ownership check failed.');
  } catch (error) {
    client.disconnect();
    if (/connection is closed/i.test(error.message)) return null;
    throw new Error('Another process owns local queue port ' + port + '. StockPilot could not verify ownership.');
  }
  try {
    const expected = await runId(client);
    if (!expected) throw new Error('The local queue broker did not return its server identity.');
    const owner = launcherPrefix + randomUUID();
    await lock(client, owner, expected);
    await client.client('SETNAME', owner);
    await unlock(client, owner, expected);
    let stopped;
    return () => stopped ??= release(client, owner, expected);
  } catch (error) {
    client.disconnect();
    if (/^LOADING/i.test(error.message)) return loading;
    if (/connection is closed/i.test(error.message)) return null;
    throw error;
  }
}

function launch(cwd, port, password) {
  const child = spawn(findServer(), ['-'], {cwd, detached:true, windowsHide:true, stdio:['pipe','ignore','ignore']});
  const attempt = {child, error:null};
  child.on('error', error => { attempt.error = error; });
  child.stdin.on('error', () => {});
  child.stdin.end([
    'bind 127.0.0.1', 'protected-mode yes', 'port ' + port, 'requirepass ' + password,
    'appendonly yes', 'appendfsync always', 'save ""', 'maxmemory-policy noeviction', 'daemonize no', '',
  ].join('\n'));
  child.unref();
  return attempt;
}

export async function startLocalBroker({directory = path.join(forecastDataDir(), '.queue-broker')} = {}) {
  await mkdir(directory, {recursive:true, mode:0o700});
  const cwd = await realpath(directory);
  // Deterministic binding prevents two processes from writing the same append-only directory.
  const key = process.platform === 'win32' ? cwd.toLowerCase() : cwd;
  const port = 20000 + createHash('sha256').update(key).digest().readUInt16BE() % 25000;
  const password = await brokerPassword(cwd);
  const deadline = Date.now() + 30000;
  let attempt, starts = 0;
  do {
    const stop = await claim('127.0.0.1', port, password);
    if (stop === loading) { await delay(100); continue; }
    if (stop) return {url:'redis://:' + password + '@127.0.0.1:' + port, stop};
    if (attempt?.error) throw attempt.error;
    // A concurrent last launcher can release the listening port while our first child is binding.
    if (!attempt || attempt.child.exitCode !== null || attempt.child.signalCode) {
      if (starts >= 3) break;
      attempt = launch(cwd, port, password);
      starts++;
    }
    await delay(100);
  } while (Date.now() < deadline);
  throw new Error('Could not start the local queue broker on port ' + port + '. Check the port and data directory.');
}
