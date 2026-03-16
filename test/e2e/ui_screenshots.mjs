import puppeteer from 'puppeteer-core';

const CHROME_PATH = 'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe';
const BASE_URL = 'http://localhost:3000';

async function run() {
  const browser = await puppeteer.launch({
    executablePath: CHROME_PATH,
    headless: true,
    args: ['--no-sandbox']
  });
  const page = await browser.newPage();
  await page.setViewport({ width: 1280, height: 800 });

  // 1. Landing page
  await page.goto(BASE_URL, { waitUntil: 'networkidle0' });
  await page.screenshot({ path: 'test/e2e/screenshots/ui_landing.png', fullPage: true });
  console.log('1. Landing page ✅');

  // 2. Install page
  await page.goto(`${BASE_URL}/install`, { waitUntil: 'networkidle0' });
  await page.screenshot({ path: 'test/e2e/screenshots/ui_install.png', fullPage: true });
  console.log('2. Install page ✅');

  // 3. Dashboard (redirects when not logged in)
  await page.goto(`${BASE_URL}/dashboard`, { waitUntil: 'networkidle0' });
  await page.screenshot({ path: 'test/e2e/screenshots/ui_dashboard_noauth.png', fullPage: true });
  console.log('3. Dashboard (no auth) ✅');

  // 4. Auth failure page
  await page.goto(`${BASE_URL}/auth/failure?message=test_error`, { waitUntil: 'networkidle0' });
  await page.screenshot({ path: 'test/e2e/screenshots/ui_auth_failure.png', fullPage: true });
  console.log('4. Auth failure redirect ✅');

  await browser.close();
  console.log('\nAll screenshots saved to test/e2e/screenshots/');
}

run().catch(err => { console.error('Error:', err.message); process.exit(1); });
