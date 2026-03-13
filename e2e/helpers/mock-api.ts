import { Page } from '@playwright/test';

/**
 * MSW-style helper to mock API responses for E2E tests.
 * Uses page.route() to intercept fetch calls to /api/v1/*.
 *
 * Since this is an embedded Shopify app, we also mock the
 * Shopify App Bridge `shopify.idToken()` call so the
 * useAuthenticatedFetch hook works without a real Shopify session.
 */

const API_BASE = '**/api/v1';

// ── Mock data ──────────────────────────────────────────────

export const mockDashboard = {
  total_skus: 142,
  low_stock_count: 8,
  out_of_stock_count: 3,
  synced_at: '2026-03-12T10:30:00Z',
  low_stock_items: [
    { id: 1, sku: 'SKU-001', title: 'Organic Cotton Tee - Black / M', available: 4, threshold: 10 },
    { id: 2, sku: 'SKU-002', title: 'Wool Beanie - Grey', available: 2, threshold: 5 },
    { id: 3, sku: 'SKU-003', title: 'Canvas Tote - Natural', available: 0, threshold: 8 },
  ],
};

export const mockProducts = {
  products: [
    { id: 1, title: 'Organic Cotton Tee', status: 'active', variants: [{ id: 10, sku: 'SKU-001', title: 'Black / M' }] },
    { id: 2, title: 'Wool Beanie', status: 'active', variants: [{ id: 20, sku: 'SKU-002', title: 'Grey' }] },
    { id: 3, title: 'Canvas Tote', status: 'active', variants: [{ id: 30, sku: 'SKU-003', title: 'Natural' }] },
    { id: 4, title: 'Denim Jacket', status: 'draft', variants: [{ id: 40, sku: 'SKU-004', title: 'Indigo / L' }, { id: 41, sku: 'SKU-005', title: 'Indigo / XL' }] },
    { id: 5, title: 'Leather Belt', status: 'active', variants: [{ id: 50, sku: 'SKU-006', title: 'Brown / 32' }] },
    { id: 6, title: 'Silk Scarf', status: 'active', variants: [{ id: 60, sku: 'SKU-007', title: 'Floral' }] },
  ],
  meta: { current_page: 1, total_pages: 3, total_count: 18, per_page: 6 },
};

export const mockProductsPage2 = {
  products: [
    { id: 7, title: 'Running Shoes', status: 'active', variants: [{ id: 70, sku: 'SKU-008', title: 'White / 10' }] },
    { id: 8, title: 'Yoga Mat', status: 'active', variants: [{ id: 80, sku: 'SKU-009', title: 'Purple' }] },
  ],
  meta: { current_page: 2, total_pages: 3, total_count: 18, per_page: 6 },
};

export const mockProductsLowStock = {
  products: [
    { id: 1, title: 'Organic Cotton Tee', status: 'active', variants: [{ id: 10, sku: 'SKU-001', title: 'Black / M' }] },
    { id: 2, title: 'Wool Beanie', status: 'active', variants: [{ id: 20, sku: 'SKU-002', title: 'Grey' }] },
  ],
  meta: { current_page: 1, total_pages: 1, total_count: 2, per_page: 6 },
};

export const mockProductsOutOfStock = {
  products: [
    { id: 3, title: 'Canvas Tote', status: 'active', variants: [{ id: 30, sku: 'SKU-003', title: 'Natural' }] },
  ],
  meta: { current_page: 1, total_pages: 1, total_count: 1, per_page: 6 },
};

export const mockSuppliers = {
  suppliers: [
    { id: 1, name: 'Textile Co.', email: 'orders@textileco.com', contact_name: 'Jane Doe', lead_time_days: 7, notes: 'Premium cotton supplier' },
    { id: 2, name: 'WoolWorks Ltd', email: 'supply@woolworks.com', contact_name: 'Bob Smith', lead_time_days: 14, notes: '' },
    { id: 3, name: 'PackagePro', email: 'hello@packagepro.com', contact_name: 'Li Wei', lead_time_days: 21, notes: 'Packaging and totes' },
  ],
};

export const mockPurchaseOrders = {
  purchase_orders: [
    {
      id: 1,
      status: 'sent',
      order_date: '2026-03-10',
      expected_delivery: '2026-03-24',
      draft_body: 'Dear Textile Co.,\n\nPlease supply the following items...',
      supplier: { id: 1, name: 'Textile Co.' },
      line_items: [
        { id: 1, sku: 'SKU-001', quantity_ordered: 50, unit_price: 12.50, variant: { title: 'Black / M', product: { title: 'Organic Cotton Tee' } } },
      ],
    },
    {
      id: 2,
      status: 'draft',
      order_date: '2026-03-12',
      expected_delivery: null,
      draft_body: 'Dear WoolWorks,\n\nWe would like to order...',
      supplier: { id: 2, name: 'WoolWorks Ltd' },
      line_items: [
        { id: 2, sku: 'SKU-002', quantity_ordered: 100, unit_price: 8.00, variant: { title: 'Grey', product: { title: 'Wool Beanie' } } },
      ],
    },
  ],
};

export const mockGeneratedDraft = {
  id: 3,
  status: 'draft',
  order_date: '2026-03-12',
  expected_delivery: '2026-03-26',
  draft_body: 'Dear Textile Co.,\n\nBased on current stock levels, we recommend ordering the following...',
  supplier: { id: 1, name: 'Textile Co.' },
  line_items: [
    { id: 3, sku: 'SKU-001', quantity_ordered: 75, unit_price: 12.50, variant: { title: 'Black / M', product: { title: 'Organic Cotton Tee' } } },
  ],
};

export const mockReports = {
  reports: [
    { id: 1, week_start: '2026-03-03', created_at: '2026-03-10T08:00:00Z', emailed_at: '2026-03-10T08:05:00Z' },
    { id: 2, week_start: '2026-02-24', created_at: '2026-03-03T08:00:00Z', emailed_at: null },
  ],
};

export const mockReportDetail = {
  id: 1,
  week_start: '2026-03-03',
  payload: {
    top_sellers: [
      { sku: 'SKU-001', title: 'Organic Cotton Tee - Black / M', units_sold: 87 },
      { sku: 'SKU-006', title: 'Leather Belt - Brown / 32', units_sold: 52 },
    ],
    stockouts: [
      { sku: 'SKU-003', title: 'Canvas Tote - Natural', triggered_at: '2026-03-07T14:22:00Z' },
    ],
    low_sku_count: 8,
    reorder_suggestions: [
      { supplier_name: 'Textile Co.', items: [{ sku: 'SKU-001', suggested_qty: 50 }] },
    ],
    ai_commentary: 'Cotton tees continue to drive strong sales this week. The canvas tote stockout on Thursday caused an estimated $240 in lost revenue. Consider increasing reorder quantities for Q2.',
  },
};

export const mockSettings = {
  alert_email: 'owner@myshop.com',
  low_stock_threshold: 10,
  timezone: 'America/Toronto',
  weekly_report_day: 'monday',
};

export const mockWebhookEndpoints = {
  webhook_endpoints: [
    { id: 1, url: 'https://hooks.slack.com/services/T00/B00/xxx', event_type: 'low_stock', is_active: true },
    { id: 2, url: 'https://example.com/webhooks/oos', event_type: 'out_of_stock', is_active: false },
  ],
};

// ── Route setup ────────────────────────────────────────────

/**
 * Inject a mock `shopify` global so useAuthenticatedFetch can call
 * `shopify.idToken()` without a real Shopify embed context.
 */
export async function injectShopifyGlobal(page: Page) {
  await page.addInitScript(() => {
    (window as unknown as Record<string, unknown>).shopify = {
      idToken: () => Promise.resolve('mock-session-token'),
    };
  });
}

/**
 * Set up all default API route mocks. Call this in `beforeEach` for
 * any test that renders the app. Individual tests can override
 * specific routes afterward.
 */
export async function setupMockApi(page: Page) {
  await injectShopifyGlobal(page);

  // Dashboard / shop endpoint
  await page.route(`${API_BASE}/shop`, (route) => {
    route.fulfill({ status: 200, contentType: 'application/json', body: JSON.stringify(mockDashboard) });
  });

  // Inventory sync
  await page.route(`${API_BASE}/inventory/sync`, (route) => {
    route.fulfill({ status: 200, contentType: 'application/json', body: JSON.stringify({ status: 'ok' }) });
  });

  // Products — handles filters and pagination
  await page.route(`${API_BASE}/products**`, (route) => {
    const url = new URL(route.request().url());
    const filter = url.searchParams.get('filter');
    const pageNum = parseInt(url.searchParams.get('page') || '1', 10);

    if (filter === 'low_stock') {
      route.fulfill({ status: 200, contentType: 'application/json', body: JSON.stringify(mockProductsLowStock) });
    } else if (filter === 'out_of_stock') {
      route.fulfill({ status: 200, contentType: 'application/json', body: JSON.stringify(mockProductsOutOfStock) });
    } else if (pageNum === 2) {
      route.fulfill({ status: 200, contentType: 'application/json', body: JSON.stringify(mockProductsPage2) });
    } else {
      route.fulfill({ status: 200, contentType: 'application/json', body: JSON.stringify(mockProducts) });
    }
  });

  // Suppliers
  await page.route(`${API_BASE}/suppliers`, (route) => {
    if (route.request().method() === 'POST') {
      route.fulfill({ status: 201, contentType: 'application/json', body: JSON.stringify({ id: 4, name: 'New Supplier', email: 'new@supplier.com', contact_name: 'Test', lead_time_days: 10, notes: '' }) });
    } else {
      route.fulfill({ status: 200, contentType: 'application/json', body: JSON.stringify(mockSuppliers) });
    }
  });

  await page.route(`${API_BASE}/suppliers/*`, (route) => {
    if (route.request().method() === 'DELETE') {
      route.fulfill({ status: 200, contentType: 'application/json', body: JSON.stringify({ status: 'ok' }) });
    } else if (route.request().method() === 'PATCH') {
      route.fulfill({ status: 200, contentType: 'application/json', body: JSON.stringify({ id: 1, name: 'Updated Supplier' }) });
    } else {
      route.fulfill({ status: 200, contentType: 'application/json', body: JSON.stringify(mockSuppliers.suppliers[0]) });
    }
  });

  // Purchase Orders
  await page.route(`${API_BASE}/purchase_orders`, (route) => {
    route.fulfill({ status: 200, contentType: 'application/json', body: JSON.stringify(mockPurchaseOrders) });
  });

  await page.route(`${API_BASE}/purchase_orders/generate_draft`, (route) => {
    route.fulfill({ status: 200, contentType: 'application/json', body: JSON.stringify(mockGeneratedDraft) });
  });

  await page.route(`${API_BASE}/purchase_orders/*/send_email`, (route) => {
    route.fulfill({ status: 200, contentType: 'application/json', body: JSON.stringify({ status: 'sent' }) });
  });

  // Reports
  await page.route(`${API_BASE}/reports`, (route) => {
    if (route.request().method() === 'POST') {
      route.fulfill({ status: 200, contentType: 'application/json', body: JSON.stringify({ status: 'ok' }) });
    } else {
      route.fulfill({ status: 200, contentType: 'application/json', body: JSON.stringify(mockReports) });
    }
  });

  await page.route(`${API_BASE}/reports/generate`, (route) => {
    route.fulfill({ status: 200, contentType: 'application/json', body: JSON.stringify({ status: 'ok' }) });
  });

  await page.route(`${API_BASE}/reports/*`, (route) => {
    route.fulfill({ status: 200, contentType: 'application/json', body: JSON.stringify(mockReportDetail) });
  });

  // Settings
  await page.route(`${API_BASE}/settings`, (route) => {
    if (route.request().method() === 'PATCH') {
      route.fulfill({ status: 200, contentType: 'application/json', body: JSON.stringify({ ...mockSettings, alert_email: 'updated@myshop.com' }) });
    } else {
      route.fulfill({ status: 200, contentType: 'application/json', body: JSON.stringify(mockSettings) });
    }
  });

  // Webhook endpoints
  await page.route(`${API_BASE}/webhook_endpoints`, (route) => {
    if (route.request().method() === 'POST') {
      route.fulfill({ status: 201, contentType: 'application/json', body: JSON.stringify({ id: 3, url: 'https://new-hook.com', event_type: 'low_stock', is_active: true }) });
    } else {
      route.fulfill({ status: 200, contentType: 'application/json', body: JSON.stringify(mockWebhookEndpoints) });
    }
  });

  await page.route(`${API_BASE}/webhook_endpoints/*`, (route) => {
    route.fulfill({ status: 200, contentType: 'application/json', body: JSON.stringify({ status: 'ok' }) });
  });
}
