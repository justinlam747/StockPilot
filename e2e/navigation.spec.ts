import { test, expect } from '@playwright/test';
import { setupMockApi } from './helpers/mock-api';

test.describe('Navigation', () => {
  test.beforeEach(async ({ page }) => {
    await setupMockApi(page);
    await page.goto('/');
  });

  test('sidebar navigation works for all routes', async ({ page }) => {
    const sidebar = page.locator('nav[aria-label="Main navigation"]');
    await expect(sidebar).toBeVisible();

    // Navigate to Inventory
    await sidebar.locator('.sidebar-item').filter({ hasText: 'Inventory' }).click();
    await expect(page).toHaveURL(/\/inventory/);
    await expect(page.locator('.grid-page-title')).toContainText('Inventory');

    // Navigate to Reports
    await sidebar.locator('.sidebar-item').filter({ hasText: 'Reports' }).click();
    await expect(page).toHaveURL(/\/reports/);
    await expect(page.locator('.grid-page-title')).toContainText('Reports');

    // Navigate to Suppliers
    await sidebar.locator('.sidebar-item').filter({ hasText: 'Suppliers' }).click();
    await expect(page).toHaveURL(/\/suppliers/);
    await expect(page.locator('.grid-page-title')).toContainText('Suppliers');

    // Navigate to Purchase Orders
    await sidebar.locator('.sidebar-item').filter({ hasText: 'Orders' }).click();
    await expect(page).toHaveURL(/\/purchase-orders/);
    await expect(page.locator('.grid-page-title')).toContainText('Purchase Orders');

    // Navigate to Agents
    await sidebar.locator('.sidebar-item').filter({ hasText: 'Agents' }).click();
    await expect(page).toHaveURL(/\/agents/);

    // Navigate to Settings (in bottom section)
    await sidebar.locator('.sidebar-item').filter({ hasText: 'Settings' }).click();
    await expect(page).toHaveURL(/\/settings/);
    await expect(page.locator('.grid-page-title')).toContainText('Settings');

    // Navigate back to Dashboard
    await sidebar.locator('.sidebar-item').filter({ hasText: 'Dashboard' }).click();
    await expect(page).toHaveURL('/');
    await expect(page.locator('.grid-page-title')).toContainText('Dashboard');
  });

  test('active state updates on navigation', async ({ page }) => {
    const sidebar = page.locator('nav[aria-label="Main navigation"]');

    // Dashboard should be active initially
    const dashboardItem = sidebar.locator('.sidebar-item').filter({ hasText: 'Dashboard' });
    await expect(dashboardItem).toHaveClass(/sidebar-item--active/);
    await expect(dashboardItem).toHaveAttribute('aria-current', 'page');

    // Navigate to Inventory
    const inventoryItem = sidebar.locator('.sidebar-item').filter({ hasText: 'Inventory' });
    await inventoryItem.click();

    // Inventory should now be active
    await expect(inventoryItem).toHaveClass(/sidebar-item--active/);
    await expect(inventoryItem).toHaveAttribute('aria-current', 'page');

    // Dashboard should no longer be active
    await expect(dashboardItem).not.toHaveClass(/sidebar-item--active/);

    // Navigate to Settings
    const settingsItem = sidebar.locator('.sidebar-item').filter({ hasText: 'Settings' });
    await settingsItem.click();

    await expect(settingsItem).toHaveClass(/sidebar-item--active/);
    await expect(settingsItem).toHaveAttribute('aria-current', 'page');
    await expect(inventoryItem).not.toHaveClass(/sidebar-item--active/);
  });

  test('sidebar collapse/expand toggle', async ({ page }) => {
    const sidebar = page.locator('nav[aria-label="Main navigation"]');

    // Find the toggle button
    const toggleButton = sidebar.locator('.sidebar-toggle');
    await expect(toggleButton).toBeVisible();

    // Initially collapsed (based on default state: expanded=false)
    await expect(sidebar).not.toHaveClass(/app-sidebar--expanded/);
    await expect(toggleButton).toHaveAttribute('aria-label', 'Expand sidebar');

    // Click to expand
    await toggleButton.click();
    await expect(sidebar).toHaveClass(/app-sidebar--expanded/);
    await expect(toggleButton).toHaveAttribute('aria-label', 'Collapse sidebar');

    // Click to collapse again
    await toggleButton.click();
    await expect(sidebar).not.toHaveClass(/app-sidebar--expanded/);
    await expect(toggleButton).toHaveAttribute('aria-label', 'Expand sidebar');
  });

  test('sidebar items have correct aria labels', async ({ page }) => {
    const sidebar = page.locator('nav[aria-label="Main navigation"]');

    // Check that all nav items have aria-label attributes
    const expectedLabels = ['Dashboard', 'Inventory', 'Reports', 'Suppliers', 'Orders', 'Agents', 'Settings'];
    for (const label of expectedLabels) {
      const item = sidebar.locator(`[aria-label="${label}"]`);
      await expect(item).toBeVisible();
    }
  });

  test('sidebar labels show text for each route', async ({ page }) => {
    const labels = page.locator('.sidebar-item-label');

    // Main nav items + settings + collapse = 8
    const expectedTexts = ['Dashboard', 'Inventory', 'Reports', 'Suppliers', 'Orders', 'Agents', 'Settings', 'Collapse'];
    for (const text of expectedTexts) {
      await expect(labels.filter({ hasText: text }).first()).toBeAttached();
    }
  });
});
