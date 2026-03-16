import puppeteer from 'puppeteer-core';

const CHROME_PATH = 'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe';
const LOCAL = 'http://localhost:3000';
const NGROK = 'https://saul-untempestuous-overdeferentially.ngrok-free.dev';

let browser;
let pass = 0, fail = 0;
const errors = [];

function assert(name, ok, detail = '') {
  if (ok) { pass++; console.log(`  ✅ ${name}`); }
  else { fail++; errors.push(detail ? `${name}: ${detail}` : name); console.log(`  ❌ ${name}${detail ? ` — ${detail}` : ''}`); }
}

async function testOAuthFlow(label, baseUrl, page) {
  console.log(`\n${'═'.repeat(60)}`);
  console.log(`  ${label}`);
  console.log(`${'═'.repeat(60)}`);

  // Clear cookies for fresh state
  const client = await page.createCDPSession();
  await client.send('Network.clearBrowserCookies');
  await client.send('Network.clearBrowserCache');

  // Collect network events
  const netLog = [];
  page.on('request', req => {
    if (req.url().includes('auth') || req.url().includes('shopify') || req.url().includes('oauth')) {
      netLog.push({ type: 'REQ', method: req.method(), url: req.url(), post: req.postData() });
    }
  });
  page.on('response', res => {
    if (res.url().includes('auth') || res.url().includes('shopify') || res.url().includes('oauth')) {
      netLog.push({ type: 'RES', status: res.status(), url: res.url(), location: res.headers()['location'] });
    }
  });

  // ── Step 1: Load install page ──
  console.log('\n── Step 1: Load install page ──');
  await page.goto(`${baseUrl}/install`, { waitUntil: 'networkidle0', timeout: 20000 });

  // Handle ngrok interstitial
  const isInterstitial = await page.evaluate(() =>
    document.body.innerText.includes('Visit Site') ||
    (document.body.innerText.includes('ngrok') && !document.body.innerText.includes('Install StockPilot'))
  );
  if (isInterstitial) {
    console.log('  Ngrok interstitial — clicking through...');
    await page.evaluate(() => {
      const btns = document.querySelectorAll('button, a');
      for (const b of btns) { if (b.innerText.includes('Visit')) { b.click(); return; } }
      const form = document.querySelector('form'); if (form) form.submit();
    });
    await page.waitForNavigation({ waitUntil: 'networkidle0', timeout: 15000 }).catch(() => {});
  }

  const onInstallPage = await page.evaluate(() => document.body.innerText.includes('Install StockPilot'));
  assert('Install page loaded', onInstallPage);
  await page.screenshot({ path: `test/e2e/screenshots/e2e_${label.replace(/\s/g,'_')}_1_install.png` });

  if (!onInstallPage) return;

  // ── Step 2: Verify form ──
  console.log('\n── Step 2: Verify form elements ──');
  const form = await page.evaluate(() => {
    const f = document.querySelector('form[action*="auth/shopify"]');
    const s = document.querySelector('input[name="shop"]');
    const c = document.querySelector('input[name="authenticity_token"]');
    const b = document.querySelector('input[type="submit"]');
    return {
      exists: !!f, action: f?.action, method: f?.method,
      shopVal: s?.value, csrfLen: c?.value?.length || 0, btnExists: !!b
    };
  });
  assert('Form exists', form.exists);
  assert('Form action includes /auth/shopify', form.action?.includes('/auth/shopify'), form.action);
  assert('Form method is POST', form.method === 'post');
  assert('Shop field has value', form.shopVal === 'stockpilot-7.myshopify.com', form.shopVal);
  assert('CSRF token present', form.csrfLen > 10, `Length: ${form.csrfLen}`);
  assert('Submit button exists', form.btnExists);

  // ── Step 3: Submit and capture redirect ──
  console.log('\n── Step 3: Submit form ──');

  await page.setRequestInterception(true);
  let oauthUrl = null;
  let failureUrl = null;
  let errorPage = null;

  const handler = async req => {
    const url = req.url();
    if (url.includes('myshopify.com') && url.includes('oauth')) {
      oauthUrl = url;
      console.log(`  → Captured Shopify redirect: ${url.substring(0, 100)}...`);
      req.abort(); // Don't actually go to Shopify
    } else if (url.includes('auth/failure')) {
      failureUrl = url;
      console.log(`  → Auth failure redirect: ${url}`);
      req.continue();
    } else {
      req.continue();
    }
  };
  page.on('request', handler);

  await page.click('input[type="submit"]');
  await new Promise(r => setTimeout(r, 5000));

  // Check what happened
  const finalUrl = page.url();

  if (!oauthUrl && !failureUrl) {
    // Check if the page shows an error
    errorPage = await page.evaluate(() => {
      const body = document.body.innerText;
      if (body.includes('InvalidAuthenticityToken')) return 'CSRF_ERROR';
      if (body.includes('invalid_site')) return 'INVALID_SITE';
      if (body.includes('Error')) return body.substring(0, 300);
      return null;
    });
  }

  page.off('request', handler);
  await page.setRequestInterception(false);
  await page.screenshot({ path: `test/e2e/screenshots/e2e_${label.replace(/\s/g,'_')}_2_result.png` });

  // ── Step 4: Validate result ──
  console.log('\n── Step 4: Validate OAuth redirect ──');

  if (oauthUrl) {
    assert('Form submit triggers Shopify redirect', true);

    const url = new URL(oauthUrl);
    const params = Object.fromEntries(url.searchParams);

    assert('Redirect host is myshopify.com', url.hostname.includes('myshopify.com'), url.hostname);
    assert('Redirect path is /admin/oauth/authorize', url.pathname === '/admin/oauth/authorize', url.pathname);
    assert('client_id correct', params.client_id === '20afdf418d6ed8240cee854d5b171a69');
    assert('redirect_uri uses ngrok', params.redirect_uri?.includes('ngrok'), params.redirect_uri);
    assert('redirect_uri ends with /auth/shopify/callback', params.redirect_uri?.endsWith('/auth/shopify/callback'));
    assert('scope: read_products', params.scope?.includes('read_products'));
    assert('scope: read_inventory', params.scope?.includes('read_inventory'));
    assert('scope: read_orders', params.scope?.includes('read_orders'));
    assert('scope: read_customers', params.scope?.includes('read_customers'));
    assert('Has state param', params.state?.length > 10);

    console.log('\n  OAuth URL details:');
    console.log(`    Host: ${url.hostname}`);
    console.log(`    redirect_uri: ${params.redirect_uri}`);
    console.log(`    scopes: ${params.scope}`);
  } else if (failureUrl) {
    assert('Form submit triggers Shopify redirect', false, `Got failure redirect: ${failureUrl}`);
  } else if (errorPage) {
    assert('Form submit triggers Shopify redirect', false, `Error: ${errorPage}`);
  } else {
    assert('Form submit triggers Shopify redirect', false, `Ended up at: ${finalUrl}`);
  }

  // ── Network log ──
  console.log('\n── Network log ──');
  netLog.forEach(e => {
    if (e.type === 'REQ') {
      console.log(`  → ${e.method} ${e.url.substring(0, 100)}`);
      if (e.post) console.log(`    POST: ${e.post.substring(0, 120)}`);
    } else {
      console.log(`  ← ${e.status} ${e.url.substring(0, 100)}`);
      if (e.location) console.log(`    Location: ${e.location.substring(0, 120)}`);
    }
  });
}

async function testStaleSession(page) {
  console.log(`\n${'═'.repeat(60)}`);
  console.log('  TEST C: Stale session (simulate browser with old cookies)');
  console.log(`${'═'.repeat(60)}`);

  // Visit some pages first to build up session state, then try oauth
  await page.goto(`${LOCAL}/dashboard`, { waitUntil: 'networkidle0' });
  await page.goto(`${LOCAL}/`, { waitUntil: 'networkidle0' });

  // Now go to install WITHOUT clearing cookies
  await page.goto(`${LOCAL}/install`, { waitUntil: 'networkidle0' });

  await page.setRequestInterception(true);
  let oauthUrl = null;
  const handler = req => {
    if (req.url().includes('myshopify.com') && req.url().includes('oauth')) {
      oauthUrl = req.url();
      req.abort();
    } else {
      req.continue();
    }
  };
  page.on('request', handler);

  await page.click('input[type="submit"]');
  await new Promise(r => setTimeout(r, 3000));

  page.off('request', handler);
  await page.setRequestInterception(false);

  assert('Stale session: OAuth still works', !!oauthUrl,
    oauthUrl ? '' : `No redirect captured. Page: ${page.url()}`);
}

async function run() {
  console.log('═'.repeat(60));
  console.log('  STOCKPILOT FULL E2E OAUTH TEST');
  console.log('═'.repeat(60));

  browser = await puppeteer.launch({
    executablePath: CHROME_PATH,
    headless: true,
    args: ['--no-sandbox']
  });

  // Test A: Localhost
  const pageA = await browser.newPage();
  await pageA.setViewport({ width: 1280, height: 800 });
  await testOAuthFlow('TEST A: Localhost', LOCAL, pageA);
  await pageA.close();

  // Test B: Ngrok
  const pageB = await browser.newPage();
  await pageB.setViewport({ width: 1280, height: 800 });
  await testOAuthFlow('TEST B: Ngrok', NGROK, pageB);
  await pageB.close();

  // Test C: Stale session
  const pageC = await browser.newPage();
  await pageC.setViewport({ width: 1280, height: 800 });
  await testStaleSession(pageC);
  await pageC.close();

  // Results
  console.log('\n' + '═'.repeat(60));
  console.log(`  RESULTS: ${pass} passed, ${fail} failed`);
  console.log('═'.repeat(60));

  if (errors.length > 0) {
    console.log('\nFAILURES:');
    errors.forEach(e => console.log(`  ❌ ${e}`));
  }

  if (fail === 0) {
    console.log('\n✅ ALL E2E TESTS PASSED');
    console.log('\nReady for browser testing:');
    console.log(`  ${NGROK}/install`);
  }

  await browser.close();
  process.exit(fail > 0 ? 1 : 0);
}

run().catch(async err => {
  console.error('Crashed:', err.message);
  if (browser) await browser.close();
  process.exit(1);
});
