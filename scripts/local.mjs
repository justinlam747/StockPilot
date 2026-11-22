import { spawnSync } from 'node:child_process';
import { existsSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const root = fileURLToPath(new URL('../', import.meta.url));
const windows = process.platform === 'win32';
const venv = path.join(root, '.venv');
const python = path.join(venv, windows ? 'Scripts/python.exe' : 'bin/python');
const next = path.join(root, 'node_modules/next/dist/bin/next');
const env = { ...process.env, NEXT_TELEMETRY_DISABLED: '1' };
const [command, ...args] = process.argv.slice(2);

function run(executable, argv) {
  const job = spawnSync(executable, argv, { cwd: root, env, stdio: 'inherit' });
  if (job.error) throw job.error;
  if (job.status !== 0) process.exit(job.status ?? 1);
}

function setup() {
  const compatible = 'import sys; sys.exit(0 if (3,11) <= sys.version_info[:2] <= (3,14) else 1)';
  if (!existsSync(python)) {
    const registered = [];
    if (windows && process.env.LOCALAPPDATA) {
      for (const minor of [14, 13, 12, 11]) {
        registered.push([path.join(process.env.LOCALAPPDATA, 'Python', 'pythoncore-3.' + minor + '-64', 'python.exe')]);
        registered.push([path.join(process.env.LOCALAPPDATA, 'Programs', 'Python', 'Python3' + minor, 'python.exe')]);
      }
    }
    const candidates = process.env.STOCKPILOT_BOOTSTRAP_PYTHON
      ? [[process.env.STOCKPILOT_BOOTSTRAP_PYTHON]]
      : windows ? [['py', '-3'], ['python'], ['python3'], ...registered] : [['python3'], ['python']];
    const choice = candidates.find(([exe, ...prefix]) =>
      spawnSync(exe, [...prefix, '-c', compatible], { stdio: 'ignore' }).status === 0);
    if (!choice) throw new Error('Install Python 3.11–3.14, then run npm run setup again.');
    run(choice[0], [...choice.slice(1), '-m', 'venv', venv]);
  }
  if (spawnSync(python, ['-c', compatible]).status !== 0) {
    throw new Error('The existing .venv needs Python 3.11–3.14. Rename it and rerun setup.');
  }
  run(python, ['-m', 'pip', 'install', '--disable-pip-version-check', '-r', 'requirements.txt']);
  if (!process.env.npm_execpath) throw new Error('Run setup through npm run setup.');
  run(process.execPath, [process.env.npm_execpath, 'ci', '--omit=dev', '--no-audit', '--no-fund']);
  console.log('StockPilot is ready. Run npm run dev and open http://127.0.0.1:3000/forecast.');
}

try {
  if (command === 'setup') {
    setup();
  } else if (['dev', 'build', 'start'].includes(command)) {
    if (!existsSync(next)) throw new Error('Install the dependencies with npm run setup first.');
    // Bind the trainer and its locally stored projects to the loopback interface.
    const bind = command === 'build' ? [] : ['--hostname', '127.0.0.1'];
    run(process.execPath, [next, command, 'forecast_app', ...args, ...bind]);
  } else {
    throw new Error('Use npm run setup, npm run dev, npm run build or npm start.');
  }
} catch (error) {
  console.error(error.message);
  process.exitCode = 1;
}
