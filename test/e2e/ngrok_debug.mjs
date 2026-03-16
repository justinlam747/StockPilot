import puppeteer from 'puppeteer-core';

const CHROME_PATH = 'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe';
const NGROK_URL = 'https://saul-untempestuous-overdeferentially.ngrok-free.dev';

async function run() {
  const browser = await puppeteer.launch({
    executablePath: CHROME_PATH,
    headless: true,
    args: ['--no-sandbox']
  });
  const page = await browser.newPage();
  await page.setViewport({ width: 1280, height: 800 });

  // Log all requests to /auth/shopify
  page.on('request', req => {
    if (req.url().includes('auth/shopify')) {
      console.log(`[REQ] ${req.method()} ${req.url()}`);
      if (req.postData()) console.log(`[POST DATA] ${req.postData()}`);
    }
  });

  page.on('response', res => {
    if (res.url().includes('auth/shopify') || res.url().includes('myshopify')) {
      console.log(`[RES] ${res.status()} ${res.url()}`);
      const location = res.headers()['location'];
      if (location) console.log(`[REDIRECT] ${location}`);
    }
  });

  // Step 1: Load install page via ngrok
  console.log('--- Step 1: Loading install page via ngrok ---');
  await page.goto(`${NGROK_URL}/install`, { waitUntil: 'networkidle0', timeout: 20000 });

  // Check for ngrok interstitial
  const bodyText = await page.evaluate(() => document.body.innerText);
  if (bodyText.includes('Visit Site') || bodyText.includes('ngrok-free')) {
    console.log('Ngrok interstitial detected — clicking through...');
    await page.screenshot({ path: 'test/e2e/screenshots/ngrok_interstitial.png' });

    // Try clicking the button
    const buttons = await page.$$('button');
    for (const btn of buttons) {
      const text = await page.evaluate(el => el.innerText, btn);
      if (text.includes('Visit')) {
        await btn.click();
        await page.waitForNavigation({ waitUntil: 'networkidle0', timeout: 15000 }).catch(() => {});
        break;
      }
    }
  }

  console.log(`Page URL: ${page.url()}`);
  await page.screenshot({ path: 'test/e2e/screenshots/ngrok_install.png' });

  // Check form elements
  const shopValue = await page.evaluate(() => {
    const input = document.querySelector('input[name="shop"]');
    return input ? input.value : 'NOT FOUND';
  });
  console.log(`Shop input value: "${shopValue}"`);

  const formAction = await page.evaluate(() => {
    const form = document.querySelector('form[action*="auth/shopify"]');
    return form ? form.action : 'NOT FOUND';
  });
  console.log(`Form action: ${formAction}`);

  // Step 2: Click connect and capture what happens
  console.log('\n--- Step 2: Clicking Connect with Shopify ---');

  await page.setRequestInterception(true);
  let oauthUrl = null;
  let errorUrl = null;

  const handler = req => {
    const url = req.url();
    if (url.includes('myshopify.com') && url.includes('oauth')) {
      oauthUrl = url;
      console.log(`\n✅ OAuth redirect captured: ${url.substring(0, 150)}...`);
      req.abort();
    } else if (url.includes('auth/failure')) {
      errorUrl = url;
      console.log(`\n❌ Auth failure redirect: ${url}`);
      req.continue();
    } else {
      req.continue();
    }
  };
  page.on('request', handler);

  try {
    await page.click('input[type="submit"]');
    await new Promise(r => setTimeout(r, 5000));
  } catch (e) {
    console.log('Click error:', e.message);
  }

  const finalUrl = page.url();
  console.log(`\nFinal URL: ${finalUrl}`);

  if (oauthUrl) {
    const url = new URL(oauthUrl);
    const params = Object.fromEntries(url.searchParams);
    console.log('\n=== OAuth URL Validated ===');
    console.log(`  Host: ${url.hostname}`);
    console.log(`  redirect_uri: ${params.redirect_uri}`);
    console.log(`  scopes: ${params.scope}`);
    console.log(`  state: ${params.state?.substring(0, 20)}...`);
    console.log('\n✅ OAuth flow works via ngrok!');
  } else if (errorUrl || finalUrl.includes('failure')) {
    console.log('\n❌ OAuth flow failed');
    await page.screenshot({ path: 'test/e2e/screenshots/ngrok_error.png' });
    const errorText = await page.evaluate(() => document.body.innerText.substring(0, 500));
    console.log('Error page content:', errorText);
  } else {
    console.log('\n❌ Unexpected result');
    await page.screenshot({ path: 'test/e2e/screenshots/ngrok_unexpected.png' });
    const text = await page.evaluate(() => document.body.innerText.substring(0, 500));
    console.log('Page content:', text);
  }

  page.off('request', handler);
  await page.setRequestInterception(false);
  await browser.close();
}

run().catch(err => { console.error('Crashed:', err.message); process.exit(1); });
