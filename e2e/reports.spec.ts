import { test, expect } from '@playwright/test';
import { setupMockApi, mockReports } from './helpers/mock-api';

test.describe('Reports Page', () => {
  test.beforeEach(async ({ page }) => {
    await setupMockApi(page);
    await page.goto('/reports');
  });

  test('reports list loads', async ({ page }) => {
    // Page title
    await expect(page.locator('.grid-page-title')).toContainText('Reports');

    // Weekly reports card
    await expect(page.locator('.grid-card-title').filter({ hasText: 'Weekly Reports' })).toBeVisible();

    // Table should be visible with reports
    const table = page.locator('.Polaris-DataTable');
    await expect(table).toBeVisible();

    // Status indicators — one sent, one pending
    await expect(page.getByText('Sent').first()).toBeVisible();
    await expect(page.getByText('Pending').first()).toBeVisible();

    // View buttons
    const viewButtons = page.getByRole('button', { name: 'View' });
    await expect(viewButtons).toHaveCount(mockReports.reports.length);
  });

  test('KPI sidebar shows report stats', async ({ page }) => {
    const sidebar = page.locator('.invg-kpi-sidebar');
    await expect(sidebar).toBeVisible();

    // Total reports
    await expect(sidebar.locator('.invg-kpi-item').filter({ hasText: 'Total Reports' }).locator('.invg-kpi-value')).toContainText(
      String(mockReports.reports.length)
    );

    // Emailed count
    await expect(sidebar.locator('.invg-kpi-item').filter({ hasText: 'Emailed' }).locator('.invg-kpi-value')).toContainText('1');

    // Pending count
    await expect(sidebar.locator('.invg-kpi-item').filter({ hasText: 'Pending' }).locator('.invg-kpi-value')).toContainText('1');
  });

  test('view report detail', async ({ page }) => {
    // Click View on first report
    const viewButton = page.getByRole('button', { name: 'View' }).first();
    await viewButton.click();

    // Should show detail view with week header
    await expect(page.locator('.grid-page-title')).toContainText('Week of');

    // Back button
    await expect(page.locator('.grid-btn--back')).toContainText('Back to Reports');

    // Top sellers table
    await expect(page.locator('.grid-card-title').filter({ hasText: 'Top Sellers' })).toBeVisible();
    await expect(page.getByText('SKU-001')).toBeVisible();
    await expect(page.getByText('Organic Cotton Tee - Black / M')).toBeVisible();

    // AI insights section
    await expect(page.locator('.grid-card-title').filter({ hasText: 'Insights' })).toBeVisible();
    await expect(page.getByText('Cotton tees continue to drive strong sales')).toBeVisible();

    // Summary sidebar with detail KPIs
    const sidebar = page.locator('.invg-kpi-sidebar');
    await expect(sidebar.locator('.invg-kpi-sidebar-title')).toContainText('Summary');
    await expect(sidebar.locator('.invg-kpi-item').filter({ hasText: 'Top Sellers' }).locator('.invg-kpi-value')).toContainText('2');
    await expect(sidebar.locator('.invg-kpi-item').filter({ hasText: 'Stockouts' }).locator('.invg-kpi-value')).toContainText('1');
    await expect(sidebar.locator('.invg-kpi-item').filter({ hasText: 'Low SKUs' }).locator('.invg-kpi-value')).toContainText('8');
  });

  test('back button returns to report list', async ({ page }) => {
    // Navigate to detail
    const viewButton = page.getByRole('button', { name: 'View' }).first();
    await viewButton.click();

    // Click back
    const backButton = page.locator('.grid-btn--back');
    await backButton.click();

    // Should show the list view again
    await expect(page.locator('.grid-card-title').filter({ hasText: 'Weekly Reports' })).toBeVisible();
  });

  test('generate report action', async ({ page }) => {
    // Generate button
    const generateButton = page.locator('.grid-btn--primary').filter({ hasText: 'Generate Report' });
    await expect(generateButton).toBeVisible();
    await expect(generateButton).toBeEnabled();

    // Click generate
    await generateButton.click();

    // Toast should confirm
    await expect(page.getByText('Report generated successfully')).toBeVisible();
  });
});
