export async function register() {
  if (process.env.NEXT_RUNTIME === 'nodejs' && process.env.NEXT_PHASE !== 'phase-production-build' &&
      process.env.STOCKPILOT_REDIS_URL) {
    const {forecastQueue} = await import('./server/forecast-queue.mjs');
    // A temporary broker error should leave the app available. Its next queue request retries the connection.
    await forecastQueue().catch(() => console.error('StockPilot will retry the local forecast queue.'));
  }
}
