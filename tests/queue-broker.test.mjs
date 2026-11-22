import assert from 'node:assert/strict';
import {spawn} from 'node:child_process';
import {createHash} from 'node:crypto';
import {mkdtemp, realpath, rm} from 'node:fs/promises';
import {tmpdir} from 'node:os';
import path from 'node:path';
import test from 'node:test';
import Redis from 'ioredis';
import {startLocalBroker, verifyExternalBroker} from '../scripts/queue-broker.mjs';
import {getRedisConnection} from '../forecast_app/server/redis-connection.mjs';

function connection(url) {
  const client = new Redis(url, {enableReadyCheck:false, retryStrategy:() => null});
  client.on('error', () => {});
  return client;
}

test('launchers share and recover one private append-only broker', async () => {
  const directory = await mkdtemp(path.join(tmpdir(), 'stockpilot-leases-'));
  const brokers = [];
  let client;
  try {
    brokers.push(...await Promise.all([startLocalBroker({directory}), startLocalBroker({directory})]));
    assert.equal(brokers[0].url, brokers[1].url);
    client = connection(brokers[0].url);
    const info = await client.info('server');
    const id = /^run_id:(\w+)/m.exec(info)[1];
    await client.set('saved-work', 'one');
    await brokers[0].stop();
    assert.equal(await client.get('saved-work'), 'one');
    await verifyExternalBroker(await getRedisConnection(brokers[1].url));
    client.disconnect();
    await brokers[1].stop();
    brokers.push(await startLocalBroker({directory}));
    client = connection(brokers[2].url);
    assert.notEqual(/^run_id:(\w+)/m.exec(await client.info('server'))[1], id);
    assert.equal(await client.get('saved-work'), 'one');
  } finally {
    client?.disconnect();
    await Promise.all(brokers.map(broker => broker.stop()));
    await rm(directory, {recursive:true, force:true, maxRetries:5});
  }
});

test('a new launcher adopts the same live broker after a launcher dies', async () => {
  const directory = await mkdtemp(path.join(tmpdir(), 'stockpilot-orphan-'));
  const module = new URL('../scripts/queue-broker.mjs', import.meta.url).href;
  const child = spawn(process.execPath, ['--input-type=module', '-e',
    'import {startLocalBroker} from ' + JSON.stringify(module) + ';' +
    'const broker = await startLocalBroker({directory:process.argv[1]}); console.log(broker.url);', directory],
  {windowsHide:true, stdio:['ignore','pipe','inherit']});
  const closed = new Promise(resolve => child.once('close', resolve));
  let adopted, client;
  try {
    const url = await new Promise((resolve, reject) => {
      let text = '';
      child.stdout.on('data', chunk => { text += chunk.toString(); if (text.includes('\n')) resolve(text.trim()); });
      child.once('error', reject);
      child.once('exit', () => reject(new Error('Test launcher exited before opening its broker.')));
    });
    client = connection(url);
    const id = /^run_id:(\w+)/m.exec(await client.info('server'))[1];
    child.kill('SIGKILL');
    await closed;
    adopted = await startLocalBroker({directory});
    assert.equal(adopted.url, url);
    assert.equal(/^run_id:(\w+)/m.exec(await client.info('server'))[1], id);
  } finally {
    client?.disconnect();
    if (child.exitCode === null && child.signalCode === null) child.kill('SIGKILL');
    await closed;
    await adopted?.stop();
    await rm(directory, {recursive:true, force:true, maxRetries:5});
  }
});

test('a passwordless Redis occupying the managed port remains available and unchanged', async () => {
  const directory = await realpath(await mkdtemp(path.join(tmpdir(), 'stockpilot-collision-')));
  const alienDir = await mkdtemp(path.join(tmpdir(), 'other-redis-'));
  const key = process.platform === 'win32' ? directory.toLowerCase() : directory;
  const port = 20000 + createHash('sha256').update(key).digest().readUInt16BE() % 25000;
  const executable = process.env.STOCKPILOT_REDIS_SERVER || (process.platform === 'win32' ?
    path.resolve('.venv/stockpilot-redis/8.10.3/redis-server.exe') : process.platform === 'darwin' ? 'valkey-server' : 'redis-server');
  const server = spawn(executable, ['-'], {cwd:alienDir, windowsHide:true, stdio:['pipe','pipe','pipe']});
  const closed = new Promise(resolve => server.once('close', resolve));
  let client;
  try {
    const ready = new Promise((resolve, reject) => {
      let log = '';
      server.on('error', reject);
      const data = chunk => { log += chunk.toString(); if (/ready to accept connections/i.test(log)) resolve(); };
      server.stdout.on('data', data);
      server.stderr.on('data', data);
      server.once('exit', () => reject(new Error('Test Redis terminated before listening.')));
    });
    server.stdin.on('error', () => {});
    server.stdin.end(['bind 127.0.0.1','protected-mode yes','port ' + port,'save ""','appendonly no',''].join('\n'));
    await ready;
    client = connection('redis://127.0.0.1:' + port);
    await client.set('other-service', 'untouched');
    await assert.rejects(startLocalBroker({directory}), /owns local queue port/);
    assert.deepEqual(await client.keys('*'), ['other-service']);
    assert.equal(await client.get('other-service'), 'untouched');
  } finally {
    client?.disconnect();
    if (server.exitCode === null && server.signalCode === null) server.kill();
    await closed;
    await rm(directory, {recursive:true, force:true, maxRetries:5});
    await rm(alienDir, {recursive:true, force:true, maxRetries:5});
  }
});
