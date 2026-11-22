import os from 'node:os';
import path from 'node:path';

export function forecastDataDir() {
  const configured = process.env.STOCKPILOT_DATA_DIR;
  if (configured) return path.resolve(configured.replace(/^~(?=$|[\\/])/, os.homedir()));
  if (process.platform === 'win32') {
    const local = process.env.LOCALAPPDATA || path.join(os.homedir(), 'AppData', 'Local');
    return path.join(local, 'StockPilot', 'forecasts');
  }
  if (process.platform === 'darwin') return path.join(os.homedir(), 'Library', 'Application Support', 'StockPilot', 'forecasts');
  return path.join(process.env.XDG_DATA_HOME || path.join(os.homedir(), '.local', 'share'), 'stockpilot', 'forecasts');
}

export async function getRedisConnection(value = process.env.STOCKPILOT_REDIS_URL) {
  if (!value) throw new Error('Start StockPilot with npm run dev or npm start to connect its local forecast queue.');
  let url;
  try { url = new URL(value); } catch { throw new Error('The local Redis connection URL is invalid.'); }
  if (url.protocol !== 'redis:' || !['127.0.0.1', 'localhost', '[::1]'].includes(url.hostname) ||
      !/^\/(\d+)?$|^$/.test(url.pathname) || url.search || url.hash) {
    throw new Error('STOCKPILOT_REDIS_URL must point to Redis on localhost.');
  }
  return {
    host: url.hostname === '[::1]' ? '::1' : url.hostname,
    port: Number(url.port || 6379),
    db: Number(url.pathname.slice(1) || 0),
    username: decodeURIComponent(url.username) || undefined,
    password: decodeURIComponent(url.password) || undefined,
  };
}
