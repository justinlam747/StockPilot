import {randomUUID} from 'node:crypto';
import {mkdir, readFile, readdir, rename, rm, stat, writeFile} from 'node:fs/promises';
import {join} from 'node:path';
import {RequestError} from './forecast-worker.mjs';

export const validJobId = id => typeof id === 'string' && /^[a-f0-9]{8}(?:-[a-f0-9]{4}){3}-[a-f0-9]{12}$/.test(id);

export function jobFiles(directory) {
  function pathFor(id, file) {
    if (!validJobId(id)) throw new RequestError(404, 'The forecast job was not found.');
    return join(directory, id, file);
  }

  async function save(id, file, data) {
    const temp = pathFor(id, randomUUID() + '.tmp');
    try {
      await writeFile(temp, JSON.stringify(data), {mode: 0o600});
      await rename(temp, pathFor(id, file));
    } finally {
      await rm(temp, {force: true});
    }
  }

  async function read(id, file) {
    try { return JSON.parse(await readFile(pathFor(id, file), 'utf8')); }
    catch (error) { if (error.code === 'ENOENT') return null; throw error; }
  }

  async function prune(queue) {
    // BullMQ bounds terminal history. Keep files for retained jobs and give an interrupted enqueue a day to settle.
    for (const entry of await readdir(directory, {withFileTypes: true})) {
      if (!entry.isDirectory() || !validJobId(entry.name)) continue;
      if (await queue.getJobState(entry.name) !== 'unknown') continue;
      const folder = pathFor(entry.name, '');
      const finished = await stat(pathFor(entry.name, 'result.json')).catch(() => null);
      const pending = await stat(folder).catch(() => null);
      if (finished || (pending && Date.now() - pending.mtimeMs > 86400000)) {
        await rm(folder, {recursive: true, force: true});
      }
    }
  }

  return {
    async putInput(id, input) {
      await mkdir(pathFor(id, ''), {recursive: true, mode: 0o700});
      await save(id, 'input.json', input);
    },
    input: id => read(id, 'input.json'),
    forgetInput: id => rm(pathFor(id, 'input.json'), {force: true}),
    saveResult: (id, data) => save(id, 'result.json', data),
    result: id => read(id, 'result.json'),
    prune,
  };
}
