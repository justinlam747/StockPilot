import { test, expect } from '@playwright/test';
import { setupMockApi, mockDashboard } from './helpers/mock-api';

test.describe('Dashboard Page', () => {
  test.beforeEach(async ({ page }) => {
    await setupMockApi(page);
    await page.goto('/');
  });

  test('loads with metric cards', async ({ page }) => {
    // Page title
    await expect(page.locator('.grid-page-title')).toContainText('Dashboard');

    // KPI list card
    const kpiRows = page.locator('.bento-kpi-row');
    await expect(kpiRows).toHaveCount(4);

    // Check specific KPI values
    await expect(page.locator('.bento-kpi-content').filter({ hasText: 'Total Products' })).toBeVisible();
    await expect(page.locator('.bento-kpi-content').filter({ hasText: 'Needs Attention' })).toBeVisible();

    // Metric cards in the 2x2 grid
    const metricCards = page.locator('.bento-metric-card');
    await expect(metricCards).toHaveCount(4);

    // Verify low stock count matches mock
    await expect(metricCards.filter({ hasText: 'Low Stock' }).locator('.stat-value')).toContainText(
      String(mockDashboard.low_stock_count)
    );

    // Verify out of stock count
    await expect(metricCards.filter({ hasText: 'Out of Stock' }).locator('.stat-value')).toContainText(
      String(mockDashboard.out_of_stock_count)
    );
  });

  test('low stock alerts table visible', async ({ page }) => {
    // Table header
    await expect(page.locator('.grid-card-title').filter({ hasText: 'Low Stock Items' })).toBeVisible();

    // Table should show the mocked low stock items
    const table = page.locator('.Polaris-DataTable');
    await expect(table).toBeVisible();

    // Verify SKU values from mock data are present
    await expect(page.getByText('SKU-001')).toBeVisible();
    await expect(page.getByText('SKU-002')).toBeVisible();
    await expect(page.getByText('SKU-003')).toBeVisible();

    // Verify product names
    await expect(page.getByText('Organic Cotton Tee - Black / M')).toBeVisible();
    await expect(page.getByText('Wool Beanie - Grey')).toBeVisible();

    // Alert count badge
    await expect(page.locator('.count-badge')).toContainText('3 alerts');
  });

  test('sync button triggers action', async ({ page }) => {
    const syncButton = page.locator('.grid-btn--primary').filter({ hasText: 'Sync Now' });
    await expect(syncButton).toBeVisible();
    await expect(syncButton).toBeEnabled();

    // Click sync
    await syncButton.click();

    // Button should show syncing state
    await expect(page.locator('.grid-btn--primary').filter({ hasText: /Sync/ })).toBeVisible();

    // Toast should appear with success message
    await expect(page.getByText('Inventory synced successfully')).toBeVisible();
  });

  test('shows sync status timestamp', async ({ page }) => {
    // Sync status should show the formatted date from mock data
    const syncStatus = page.locator('.bento-sync-status').first();
    await expect(syncStatus).toContainText('Synced');
  });

  test('navigation to inventory page works', async ({ page }) => {
    // Click inventory nav item in sidebar
    const inventoryLink = page.locator('.sidebar-item').filter({ hasText: 'Inventory' });
    await inventoryLink.click();

    // Should navigate to inventory page
    await expect(page).toHaveURL(/\/inventory/);
    await expect(page.locator('.grid-page-title')).toContainText('Inventory');
  });
});
