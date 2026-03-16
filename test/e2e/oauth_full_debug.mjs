import puppeteer from 'puppeteer-core';

const CHROME_PATH = 'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe';
const LOCAL = 'http://localhost:3000';
const NGROK = 'https://saul-untempestuous-overdeferentially.ngrok-free.dev';

let browser, page;
let step = 0;

async function ss(name) {
  step++;
  const file = `test/e2e/screenshots/debug_${String(step).padStart(2,'0')}_${name}.png`;
  await page.screenshot({ path: file, fullPage: true });
  console.log(`  📸 ${file}`);
}

async function logPage(label) {
  const url = page.url();
  const title = await page.title().catch(() => '(no title)');
  const text = await page.evaluate(() => document.body?.innerText?.substring(0, 200) || '').catch(() => '');
  console.log(`  URL: ${url}`);
  console.log(`  Title: ${title}`);
  if (text) console.log(`  Body: ${text.replace(/\n/g, ' ').substring(0, 150)}`);
}

async function run() {
  console.log('='.repeat(60));
  console.log('  FULL OAUTH DEBUG — EVERY STEP');
  console.log('='.repeat(60));

  browser = await puppeteer.launch({
    executablePath: CHROME_PATH,
    headless: true,
    args: ['--no-sandbox', '--disable-web-security']
  });
  page = await browser.newPage();
  await page.setViewport({ width: 1280, height: 800 });

  // Capture ALL network traffic
  const requests = [];
  const responses = [];

  page.on('request', req => {
    const url = req.url();
    if (url.includes('auth') || url.includes('shopify') || url.includes('oauth') || url.includes('myshopify')) {
      const entry = { method: req.method(), url, postData: req.postData() || null };
      requests.push(entry);
      console.log(`  [→ ${req.method()}] ${url.substring(0, 120)}`);
      if (req.postData()) {
        console.log(`  [POST] ${req.postData().substring(0, 200)}`);
      }
    }
  });

  page.on('response', res => {
    const url = res.url();
    if (url.includes('auth') || url.includes('shopify') || url.includes('oauth') || url.includes('myshopify')) {
      const location = res.headers()['location'] || '';
      const entry = { status: res.status(), url, location };
      responses.push(entry);
      console.log(`  [← ${res.status()}] ${url.substring(0, 120)}`);
      if (location) console.log(`  [LOCATION] ${location.substring(0, 150)}`);
    }
  });

  // ═══════════════════════════════════════════
  // TEST A: Via localhost (baseline)
  // ═══════════════════════════════════════════
  console.log('\n' + '─'.repeat(60));
  console.log('TEST A: OAuth via LOCALHOST (baseline)');
  console.log('─'.repeat(60));

  console.log('\nA1. Loading install page...');
  await page.goto(`${LOCAL}/install`, { waitUntil: 'networkidle0' });
  await ss('A1_localhost_install');
  await logPage('A1');

  // Verify form renders correctly
  const formA = await page.evaluate(() => {
    const form = document.querySelector('form[action*="auth/shopify"]');
    const shop = document.querySelector('input[name="shop"]');
    const csrf = document.querySelector('input[name="authenticity_token"]');
    const submit = document.querySelector('input[type="submit"]');
    return {
      formExists: !!form,
      action: form?.action || 'MISSING',
      method: form?.method || 'MISSING',
      shopValue: shop?.value || 'MISSING',
      csrfExists: !!csrf,
      csrfValue: csrf?.value?.substring(0, 20) || 'MISSING',
      submitExists: !!submit,
      submitValue: submit?.value || 'MISSING'
    };
  });
  console.log('\n  Form analysis:', JSON.stringify(formA, null, 4));

  console.log('\nA2. Submitting form (following redirects naturally)...');

  // Don't intercept — let it flow naturally
  const navPromise = page.waitForNavigation({ waitUntil: 'networkidle0', timeout: 10000 }).catch(e => e);
  await page.click('input[type="submit"]');
  await navPromise;

  await ss('A2_after_submit');
  await logPage('A2');

  const urlAfterSubmitA = page.url();
  if (urlAfterSubmitA.includes('myshopify.com') && urlAfterSubmitA.includes('oauth')) {
    console.log('\n  ✅ A: Localhost OAuth redirect works!');
  } else if (urlAfterSubmitA.includes('myshopify.com')) {
    console.log('\n  ✅ A: Reached Shopify (maybe login page)');
  } else if (urlAfterSubmitA.includes('failure') || urlAfterSubmitA.includes('invalid')) {
    console.log('\n  ❌ A: OAuth failed');
    const errorText = await page.evaluate(() => document.body.innerText.substring(0, 500));
    console.log('  Error:', errorText.replace(/\n/g, ' ').substring(0, 300));
  } else {
    console.log('\n  ⚠️ A: Unexpected URL after submit');
  }

  // ═══════════════════════════════════════════
  // TEST B: Via ngrok (real tunnel)
  // ═══════════════════════════════════════════
  console.log('\n' + '─'.repeat(60));
  console.log('TEST B: OAuth via NGROK (real tunnel)');
  console.log('─'.repeat(60));

  // Clear cookies for fresh session
  const client = await page.createCDPSession();
  await client.send('Network.clearBrowserCookies');
  console.log('\n  Cleared all cookies');

  console.log('\nB1. Loading install page via ngrok...');
  await page.goto(`${NGROK}/install`, { waitUntil: 'networkidle0', timeout: 20000 });
  await ss('B1_ngrok_initial');
  await logPage('B1');

  // Handle ngrok interstitial
  const isInterstitial = await page.evaluate(() => {
    return document.body.innerText.includes('Visit Site') ||
           document.body.innerText.includes('ngrok') && !document.body.innerText.includes('Install StockPilot');
  });

  if (isInterstitial) {
    console.log('\n  Ngrok interstitial detected — clicking through...');
    await ss('B1b_interstitial');

    // Try multiple ways to click through
    const clicked = await page.evaluate(() => {
      const buttons = document.querySelectorAll('button, a');
      for (const btn of buttons) {
        if (btn.innerText.includes('Visit') || btn.innerText.includes('Continue')) {
          btn.click();
          return true;
        }
      }
      // Try the form submit
      const form = document.querySelector('form');
      if (form) { form.submit(); return true; }
      return false;
    });

    if (clicked) {
      await page.waitForNavigation({ waitUntil: 'networkidle0', timeout: 15000 }).catch(() => {});
    }

    await ss('B1c_after_interstitial');
    await logPage('B1c');
  }

  // Verify we're on the install page
  const onInstall = await page.evaluate(() =>
    document.body.innerText.includes('Install StockPilot'));

  if (!onInstall) {
    console.log('\n  ❌ Not on install page after ngrok. Aborting.');
    await ss('B1_fail');
    await browser.close();
    return;
  }
  console.log('\n  ✅ On install page via ngrok');

  // Verify form elements via ngrok
  const formB = await page.evaluate(() => {
    const form = document.querySelector('form[action*="auth/shopify"]');
    const shop = document.querySelector('input[name="shop"]');
    const csrf = document.querySelector('input[name="authenticity_token"]');
    return {
      formExists: !!form,
      action: form?.action || 'MISSING',
      method: form?.method || 'MISSING',
      shopValue: shop?.value || 'MISSING',
      csrfExists: !!csrf,
      csrfLength: csrf?.value?.length || 0
    };
  });
  console.log('  Form via ngrok:', JSON.stringify(formB, null, 4));

  console.log('\nB2. Submitting form via ngrok...');

  const navPromiseB = page.waitForNavigation({ waitUntil: 'networkidle0', timeout: 15000 }).catch(e => e);
  await page.click('input[type="submit"]');
  await navPromiseB;

  // Wait a bit more for any additional redirects
  await new Promise(r => setTimeout(r, 2000));

  await ss('B2_after_submit_ngrok');
  await logPage('B2');

  const urlAfterSubmitB = page.url();

  if (urlAfterSubmitB.includes('myshopify.com') && urlAfterSubmitB.includes('oauth')) {
    console.log('\n  ✅ B: Ngrok OAuth redirect to Shopify authorize page!');
  } else if (urlAfterSubmitB.includes('myshopify.com/admin')) {
    console.log('\n  ✅ B: Reached Shopify admin (login required)');
    await ss('B3_shopify_login');
  } else if (urlAfterSubmitB.includes('accounts.shopify.com')) {
    console.log('\n  ✅ B: Reached Shopify accounts login page');
    await ss('B3_shopify_accounts');
  } else {
    console.log('\n  ❌ B: Unexpected destination');
    const errorText = await page.evaluate(() => document.body.innerText.substring(0, 500));
    console.log('  Page content:', errorText.replace(/\n/g, ' ').substring(0, 400));
    await ss('B2_error');
  }

  // ═══════════════════════════════════════════
  // NETWORK LOG SUMMARY
  // ═══════════════════════════════════════════
  console.log('\n' + '─'.repeat(60));
  console.log('NETWORK LOG SUMMARY');
  console.log('─'.repeat(60));

  console.log('\nAll auth-related requests:');
  requests.forEach((r, i) => {
    console.log(`  ${i+1}. ${r.method} ${r.url.substring(0, 120)}`);
    if (r.postData) console.log(`     POST: ${r.postData.substring(0, 150)}`);
  });

  console.log('\nAll auth-related responses:');
  responses.forEach((r, i) => {
    console.log(`  ${i+1}. ${r.status} ${r.url.substring(0, 120)}`);
    if (r.location) console.log(`     → ${r.location.substring(0, 150)}`);
  });

  await browser.close();
}

run().catch(async (err) => {
  console.error('Test crashed:', err.message);
  if (browser) await browser.close();
  process.exit(1);
});
