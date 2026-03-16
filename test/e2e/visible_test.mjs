import puppeteer from 'puppeteer-core';

const CHROME = 'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe';
const NGROK = 'https://saul-untempestuous-overdeferentially.ngrok-free.dev';

const browser = await puppeteer.launch({
  executablePath: CHROME,
  headless: false,
  args: ['--no-sandbox', '--start-maximized']
});
const page = await browser.newPage();
await page.setViewport({ width: 1280, height: 900 });

// Log everything
page.on('response', res => {
  const url = res.url();
  if (url.includes('auth') || url.includes('shopify') || url.includes('oauth')) {
    const loc = res.headers()['location'] || '';
    console.log(`[${res.status()}] ${url.substring(0, 100)}`);
    if (loc) console.log(`  → ${loc.substring(0, 120)}`);
  }
});

console.log('1. Loading install page via ngrok...');
await page.goto(`${NGROK}/install`, { waitUntil: 'networkidle0', timeout: 20000 });

// Handle ngrok interstitial
const needsClick = await page.evaluate(() =>
  !document.body.innerText.includes('Install StockPilot'));
if (needsClick) {
  console.log('   Clicking through ngrok interstitial...');
  await page.evaluate(() => {
    for (const b of document.querySelectorAll('button, a'))
      if (b.innerText.includes('Visit')) { b.click(); return; }
  });
  await page.waitForNavigation({ waitUntil: 'networkidle0', timeout: 15000 }).catch(() => {});
}

console.log('2. On install page. Clicking Connect...');
await page.click('input[type="submit"]');

// Let it navigate fully — don't intercept
console.log('3. Waiting for redirects...');
await new Promise(r => setTimeout(r, 10000));

const finalUrl = page.url();
console.log(`4. Final URL: ${finalUrl}`);
await page.screenshot({ path: 'test/e2e/screenshots/visible_result.png', fullPage: true });

const bodyText = await page.evaluate(() => document.body.innerText.substring(0, 500));
console.log(`5. Page content: ${bodyText.substring(0, 300)}`);

// Keep open so user can see
console.log('\nBrowser will stay open for 60 seconds...');
await new Promise(r => setTimeout(r, 60000));
await browser.close();
