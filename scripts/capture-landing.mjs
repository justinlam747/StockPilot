import puppeteer from 'puppeteer';
import { fileURLToPath } from 'url';
import path from 'path';

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const __dirname = path.dirname(fileURLToPath(import.meta.url));

async function run() {
  const browser = await puppeteer.launch({
    headless: true,
    defaultViewport: { width: 1280, height: 2400, deviceScaleFactor: 2 },
    args: ['--no-sandbox'],
  });

  const page = await browser.newPage();
  await page.goto('http://localhost:3000/', { waitUntil: 'networkidle0', timeout: 15000 });
  await sleep(1000);

  await page.screenshot({
    path: path.join(__dirname, '..', 'public', 'images', 'screenshots', 'landing-preview.png'),
    fullPage: true,
  });

  await browser.close();
  console.log('Saved landing-preview.png');
}

run().catch(console.error);
