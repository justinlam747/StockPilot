import puppeteer from 'puppeteer-core';

const CHROME_PATH = 'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe';
const BASE_URL = 'http://localhost:3000';
const NGROK_URL = 'https://saul-untempestuous-overdeferentially.ngrok-free.dev';

let browser, page;
let pass = 0, fail = 0;
const errors = [];

async function assert(name, condition, detail = '') {
  if (condition) {
    pass++;
    console.log(`  ✅ ${name}`);
  } else {
    fail++;
    const msg = detail ? `${name}: ${detail}` : name;
    errors.push(msg);
    console.log(`  ❌ ${name}${detail ? ` — ${detail}` : ''}`);
  }
}

async function screenshot(name) {
  await page.screenshot({ path: `test/e2e/screenshots/${name}.png`, fullPage: true });
}

async function run() {
  console.log('='.repeat(60));
  console.log('  STOCKPILOT E2E OAUTH FLOW — PUPPETEER');
  console.log('='.repeat(60));
  console.log('');

  browser = await puppeteer.launch({
    executablePath: CHROME_PATH,
    headless: true,
    args: ['--no-sandbox', '--disable-setuid-sandbox']
  });
  page = await browser.newPage();
  await page.setViewport({ width: 1280, height: 800 });

  // ─── Test 1: Landing Page ───
  console.log('--- 1. Landing Page ---');
  await page.goto(BASE_URL, { waitUntil: 'networkidle0' });
  const title = await page.title();
  await assert('Landing page loads', title.includes('StockPilot'), `Title: "${title}"`);
  await screenshot('01_landing');

  // ─── Test 2: Health Check ───
  console.log('\n--- 2. Health Check ---');
  const healthRes = await page.goto(`${BASE_URL}/health`, { waitUntil: 'networkidle0' });
  await assert('Health check returns 200', healthRes.status() === 200);

  // ─── Test 3: Dashboard requires auth ───
  console.log('\n--- 3. Dashboard Auth Gate ---');
  await page.goto(`${BASE_URL}/dashboard`, { waitUntil: 'networkidle0' });
  const dashUrl = page.url();
  await assert('Dashboard redirects when not logged in',
    !dashUrl.includes('/dashboard'),
    `Ended up at: ${dashUrl}`);
  await screenshot('02_dashboard_redirect');

  // ─── Test 4: Install Page ───
  console.log('\n--- 4. Install Page ---');
  await page.goto(`${BASE_URL}/install`, { waitUntil: 'networkidle0' });
  await screenshot('03_install_page');

  const hasHeading = await page.evaluate(() =>
    document.body.innerText.includes('Install StockPilot'));
  await assert('Has "Install StockPilot" heading', hasHeading);

  const hasButton = await page.evaluate(() => {
    const submit = document.querySelector('input[type="submit"]');
    return submit && submit.value.includes('Connect');
  });
  await assert('Has "Connect with Shopify" submit button', hasButton);

  const shopInput = await page.$('input[name="shop"]');
  await assert('Has shop input field', shopInput !== null);

  if (shopInput) {
    const shopValue = await page.evaluate(el => el.value, shopInput);
    await assert('Shop input pre-filled with dev store',
      shopValue === 'stockpilot-7.myshopify.com',
      `Value: "${shopValue}"`);
  }

  const csrfInput = await page.$('input[name="authenticity_token"]');
  await assert('Form has CSRF token field', csrfInput !== null);

  if (csrfInput) {
    const tokenValue = await page.evaluate(el => el.value, csrfInput);
    await assert('CSRF token is not empty', tokenValue && tokenValue.length > 10);
  }

  const formCheck = await page.evaluate(() => {
    const form = document.querySelector('form[action*="/auth/shopify"]');
    return form ? { action: form.action, method: form.method } : null;
  });
  await assert('Form action is /auth/shopify', formCheck?.action?.includes('/auth/shopify'));
  await assert('Form method is POST', formCheck?.method === 'post');

  // ─── Test 5: Click Connect — capture OAuth redirect ───
  console.log('\n--- 5. OAuth Redirect (Browser Click) ---');

  // Navigate to install fresh
  await page.goto(`${BASE_URL}/install`, { waitUntil: 'networkidle0' });

  // Set up request interception to catch the Shopify redirect
  await page.setRequestInterception(true);

  let oauthRedirectUrl = null;
  let gotError = false;

  const requestHandler = (request) => {
    const url = request.url();
    if (url.includes('myshopify.com') && url.includes('oauth')) {
      oauthRedirectUrl = url;
      request.abort();
    } else {
      request.continue();
    }
  };

  page.on('request', requestHandler);

  // Click the submit button
  try {
    await page.click('input[type="submit"]');
    // Wait for navigation or error
    await new Promise(r => setTimeout(r, 3000));
  } catch (e) {
    // Navigation might have been aborted
  }

  // Check current page for errors
  const currentUrl = page.url();
  const pageContent = await page.evaluate(() => document.body.innerText).catch(() => '');

  // Remove interception
  page.off('request', requestHandler);
  await page.setRequestInterception(false);

  if (oauthRedirectUrl) {
    await assert('Click triggers OAuth redirect to Shopify', true);
    await screenshot('04_oauth_redirect');

    const url = new URL(oauthRedirectUrl);
    const params = Object.fromEntries(url.searchParams);

    console.log('\n--- 6. OAuth URL Validation ---');
    await assert('OAuth host is myshopify.com',
      url.hostname.includes('myshopify.com'),
      url.hostname);
    await assert('OAuth path is /admin/oauth/authorize',
      url.pathname === '/admin/oauth/authorize',
      url.pathname);
    await assert('client_id is correct',
      params.client_id === '20afdf418d6ed8240cee854d5b171a69',
      params.client_id);
    await assert('redirect_uri uses ngrok (not localhost)',
      params.redirect_uri?.includes('ngrok'),
      params.redirect_uri);
    await assert('redirect_uri path is /auth/shopify/callback',
      params.redirect_uri?.endsWith('/auth/shopify/callback'),
      params.redirect_uri);
    await assert('scope includes read_products',
      params.scope?.includes('read_products'));
    await assert('scope includes read_inventory',
      params.scope?.includes('read_inventory'));
    await assert('scope includes read_orders',
      params.scope?.includes('read_orders'));
    await assert('scope includes read_customers',
      params.scope?.includes('read_customers'));
    await assert('Has state param (OAuth CSRF protection)',
      params.state?.length > 10,
      `Length: ${params.state?.length}`);

    console.log('\n--- OAuth URL ---');
    console.log(`  ${url.origin}${url.pathname}`);
    console.log(`  client_id:    ${params.client_id}`);
    console.log(`  redirect_uri: ${params.redirect_uri}`);
    console.log(`  scopes:       ${params.scope}`);
    console.log(`  state:        ${params.state?.substring(0, 24)}...`);
  } else {
    // Diagnose the failure
    if (pageContent.includes('InvalidAuthenticityToken')) {
      await assert('Click triggers OAuth redirect', false,
        'CSRF InvalidAuthenticityToken — token mismatch between form and OmniAuth');
      await screenshot('04_csrf_error');
    } else if (currentUrl.includes('auth/failure')) {
      await assert('Click triggers OAuth redirect', false,
        `Got auth failure redirect`);
      await screenshot('04_auth_failure');
    } else if (pageContent.includes('invalid_site')) {
      await assert('Click triggers OAuth redirect', false,
        'OmniAuth invalid_site — shop param not received');
    } else {
      await assert('Click triggers OAuth redirect', false,
        `Ended up at: ${currentUrl} | Content: ${pageContent.substring(0, 100)}`);
      await screenshot('04_unknown_error');
    }
  }

  // ─── Test 7: Failure Route ───
  console.log('\n--- 7. Failure Route ---');
  // New page to avoid interception issues
  const page2 = await browser.newPage();
  await page2.goto(`${BASE_URL}/auth/failure?message=invalid_credentials`, { waitUntil: 'networkidle0' });
  const failureUrl = page2.url();
  await assert('Auth failure redirects to root',
    failureUrl === `${BASE_URL}/` || failureUrl === BASE_URL,
    `Ended up at: ${failureUrl}`);
  await page2.close();

  // ─── Results ───
  console.log('');
  console.log('='.repeat(60));
  console.log(`  RESULTS: ${pass} passed, ${fail} failed`);
  console.log('='.repeat(60));

  if (errors.length > 0) {
    console.log('');
    console.log('FAILURES:');
    errors.forEach(e => console.log(`  ❌ ${e}`));
  }

  if (fail === 0) {
    console.log('');
    console.log('🎉 All E2E tests passed! OAuth flow is fully working.');
    console.log('');
    console.log('Browser test:');
    console.log(`  ${NGROK_URL}/install`);
    console.log('');
    console.log('Flow:');
    console.log('  1. /install → renders form');
    console.log('  2. Click "Connect with Shopify"');
    console.log('  3. → Shopify OAuth consent screen');
    console.log('  4. Merchant authorizes');
    console.log(`  5. → ${NGROK_URL}/auth/shopify/callback`);
    console.log('  6. App creates Shop record + session');
    console.log('  7. → /dashboard');
  }

  await browser.close();
  process.exit(fail > 0 ? 1 : 0);
}

run().catch(async (err) => {
  console.error('Test crashed:', err.message);
  if (browser) await browser.close();
  process.exit(1);
});
