import puppeteer from 'puppeteer';
import { fileURLToPath } from 'url';
import path from 'path';
import fs from 'fs';

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const __dirname = path.dirname(fileURLToPath(import.meta.url));
const outputDir = path.join(__dirname, '..', 'public', 'images', 'screenshots');

const BASE = 'http://localhost:3000';

async function run() {
  const browser = await puppeteer.launch({
    headless: true,
    defaultViewport: { width: 1280, height: 900, deviceScaleFactor: 2 },
    args: ['--no-sandbox'],
  });

  const page = await browser.newPage();
  fs.mkdirSync(outputDir, { recursive: true });

  // Hide sidebar
  await page.evaluateOnNewDocument(() => {
    const style = document.createElement('style');
    style.textContent = `
      #sidebar, .sidebar { display: none !important; }
      .app-frame { margin-left: 0 !important; padding-left: 0 !important; }
      .app-frame__content { margin-left: 0 !important; padding-left: 24px !important; }
    `;
    document.addEventListener('DOMContentLoaded', () => document.head.appendChild(style));
  });

  // Login
  console.log('Logging in...');
  await page.goto(`${BASE}/dev/login`, { waitUntil: 'networkidle0', timeout: 15000 });
  await sleep(1000);

  // ALERTS — tight clip around header + rows
  console.log('Capturing alerts...');
  await page.goto(`${BASE}/alerts`, { waitUntil: 'networkidle0', timeout: 15000 });
  await sleep(600);
  let clip = await page.evaluate(() => {
    const header = document.querySelector('.alt-header');
    const rows = document.querySelectorAll('.alt-row');
    if (!header) return null;
    const hRect = header.getBoundingClientRect();
    let bottom = hRect.bottom;
    rows.forEach(r => { const rr = r.getBoundingClientRect(); if (rr.bottom > bottom) bottom = rr.bottom; });
    return { x: Math.max(0, hRect.x - 8), y: Math.max(0, hRect.y - 8), width: Math.min(hRect.width + 16, 800), height: bottom - hRect.top + 20 };
  });
  await page.screenshot({ path: path.join(outputDir, 'alerts.png'), clip: clip || undefined });
  console.log('  Saved alerts.png');

  // PURCHASE ORDERS — use narrower viewport to fill the card, clip just the card
  console.log('Capturing purchase-orders...');
  await page.setViewport({ width: 700, height: 900, deviceScaleFactor: 2 });
  await page.goto(`${BASE}/purchase_orders`, { waitUntil: 'networkidle0', timeout: 15000 });
  await sleep(600);
  clip = await page.evaluate(() => {
    const header = document.querySelector('.po-header');
    const card = document.querySelector('.po-card') || document.querySelector('.po-grid') || document.querySelector('#po-list');
    if (!header) return null;
    const hRect = header.getBoundingClientRect();
    const endEl = card || header;
    const eRect = endEl.getBoundingClientRect();
    return { x: Math.max(0, hRect.x - 8), y: Math.max(0, hRect.y - 8), width: Math.min(hRect.width + 16, 680), height: eRect.bottom - hRect.top + 20 };
  });
  await page.screenshot({ path: path.join(outputDir, 'purchase-orders.png'), clip: clip || undefined });
  console.log('  Saved purchase-orders.png');
  await page.setViewport({ width: 1280, height: 900, deviceScaleFactor: 2 });

  // SUPPLIERS — tight clip
  console.log('Capturing suppliers...');
  await page.goto(`${BASE}/suppliers`, { waitUntil: 'networkidle0', timeout: 15000 });
  await sleep(600);
  clip = await page.evaluate(() => {
    const header = document.querySelector('.sup-header');
    const grid = document.querySelector('.sup-grid');
    if (!header || !grid) return null;
    const hRect = header.getBoundingClientRect();
    const gRect = grid.getBoundingClientRect();
    return { x: Math.max(0, hRect.x - 8), y: Math.max(0, hRect.y - 8), width: Math.min(gRect.width + 16, 1100), height: gRect.bottom - hRect.top + 20 };
  });
  await page.screenshot({ path: path.join(outputDir, 'suppliers.png'), clip: clip || undefined });
  console.log('  Saved suppliers.png');

  // DASHBOARD — full bento grid (for weekly reports box)
  console.log('Capturing dashboard...');
  await page.goto(`${BASE}/dashboard`, { waitUntil: 'networkidle0', timeout: 15000 });
  await sleep(600);
  clip = await page.evaluate(() => {
    const bento = document.querySelector('.bento');
    if (!bento) return null;
    const r = bento.getBoundingClientRect();
    return { x: Math.max(0, r.x - 4), y: Math.max(0, r.y - 4), width: r.width + 8, height: r.height + 8 };
  });
  await page.screenshot({ path: path.join(outputDir, 'dashboard.png'), clip: clip || undefined });
  console.log('  Saved dashboard.png');

  // DASHBOARD AI AGENT TILE — just the agent tile for smart reorder
  console.log('Capturing agent tile...');
  clip = await page.evaluate(() => {
    const tile = document.querySelector('.bento__tile--feature');
    if (!tile) return null;
    const r = tile.getBoundingClientRect();
    return { x: Math.max(0, r.x - 4), y: Math.max(0, r.y - 4), width: r.width + 8, height: r.height + 8 };
  });
  await page.screenshot({ path: path.join(outputDir, 'agent-tile.png'), clip: clip || undefined });
  console.log('  Saved agent-tile.png');

  // INVENTORY DETAIL — chart + variants
  console.log('Capturing inventory detail...');
  await page.goto(`${BASE}/inventory`, { waitUntil: 'networkidle0', timeout: 15000 });
  const link = await page.evaluate(() => {
    const a = document.querySelector('a[href*="/inventory/"]');
    return a ? a.getAttribute('href') : null;
  });
  if (link) {
    await page.goto(`${BASE}${link}`, { waitUntil: 'networkidle0', timeout: 15000 });
    await sleep(600);
    clip = await page.evaluate(() => {
      const header = document.querySelector('.pdp-header');
      const variants = document.querySelector('.pdp-variants');
      if (!header) return null;
      const hRect = header.getBoundingClientRect();
      const endEl = variants || header;
      const eRect = endEl.getBoundingClientRect();
      return { x: Math.max(0, hRect.x - 8), y: Math.max(0, hRect.y - 8), width: Math.min(hRect.width + 16, 1100), height: eRect.bottom - hRect.top + 20 };
    });
    await page.screenshot({ path: path.join(outputDir, 'inventory-detail.png'), clip: clip || undefined });
    console.log('  Saved inventory-detail.png');
  }

  // INVENTORY GRID — table view (more compact, no missing images)
  console.log('Capturing inventory table view...');
  await page.goto(`${BASE}/inventory`, { waitUntil: 'networkidle0', timeout: 15000 });
  await sleep(600);
  // Click table view toggle if it exists
  await page.evaluate(() => {
    const tableBtn = document.querySelector('[aria-label*="table"], [aria-label*="Table"], .inv-view-toggle button:last-child, .inv-toolbar__views button:last-child');
    if (tableBtn) tableBtn.click();
  });
  await sleep(600);
  clip = await page.evaluate(() => {
    const header = document.querySelector('.inv-header');
    const table = document.querySelector('.inv-table-wrap') || document.querySelector('table') || document.querySelector('.inv-grid');
    if (!header) return null;
    const hRect = header.getBoundingClientRect();
    const endEl = table || header;
    const eRect = endEl.getBoundingClientRect();
    return { x: Math.max(0, hRect.x - 8), y: Math.max(0, hRect.y - 8), width: Math.min(hRect.width + 16, 1100), height: Math.min(eRect.bottom - hRect.top + 20, 700) };
  });
  await page.screenshot({ path: path.join(outputDir, 'inventory-table.png'), clip: clip || undefined });
  console.log('  Saved inventory-table.png');

  await browser.close();
  console.log('\nDone!');
}

run().catch(console.error);
