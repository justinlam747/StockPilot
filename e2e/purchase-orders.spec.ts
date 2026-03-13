import { test, expect } from '@playwright/test';
import { setupMockApi, mockPurchaseOrders } from './helpers/mock-api';

test.describe('Purchase Orders Page', () => {
  test.beforeEach(async ({ page }) => {
    await setupMockApi(page);
    await page.goto('/purchase-orders');
  });

  test('PO list loads', async ({ page }) => {
    // Page title
    await expect(page.locator('.grid-page-title')).toContainText('Purchase Orders');

    // AI badge
    await expect(page.locator('.ai-badge').first()).toContainText('AI');

    // Order history table
    await expect(page.locator('.grid-card-title').filter({ hasText: 'Order History' })).toBeVisible();

    // DataTable renders inside the grid-card — verify the table element is visible
    const table = page.locator('.grid-card').filter({ hasText: 'Order History' }).locator('table');
    await expect(table).toBeVisible();

    // Verify PO data from mocks — scope to table to avoid hidden <option> elements
    const historyCard = page.locator('.grid-card').filter({ hasText: 'Order History' });
    await expect(historyCard.getByText('Textile Co.')).toBeVisible();
    await expect(historyCard.getByText('WoolWorks Ltd')).toBeVisible();
    await expect(page.getByText('2026-03-10')).toBeVisible();

    // Status indicators
    await expect(page.getByText('SENT').first()).toBeVisible();
    await expect(page.getByText('DRAFT').first()).toBeVisible();
  });

  test('KPI sidebar shows order stats', async ({ page }) => {
    const sidebar = page.locator('.invg-kpi-sidebar');
    await expect(sidebar).toBeVisible();

    // Total orders
    await expect(sidebar.locator('.invg-kpi-item').filter({ hasText: 'Total Orders' }).locator('.invg-kpi-value')).toContainText(
      String(mockPurchaseOrders.purchase_orders.length)
    );

    // Sent count
    await expect(sidebar.locator('.invg-kpi-item').filter({ hasText: 'Sent' }).locator('.invg-kpi-value')).toContainText('1');

    // Drafts count
    await expect(sidebar.locator('.invg-kpi-item').filter({ hasText: 'Drafts' }).locator('.invg-kpi-value')).toContainText('1');
  });

  test('create PO flow works', async ({ page }) => {
    // Generate draft section should be visible
    await expect(page.locator('.grid-card-title').filter({ hasText: 'Generate Draft PO' })).toBeVisible();

    // Supplier dropdown should have options — use label selector to find the Select component
    await expect(page.locator('label').getByText('Supplier')).toBeVisible();

    // Click generate draft
    const generateButton = page.locator('.grid-btn--primary').filter({ hasText: 'Generate Draft' });
    await expect(generateButton).toBeVisible();
    await generateButton.click();

    // Toast should confirm generation
    await expect(page.getByText('Draft PO generated successfully')).toBeVisible();

    // PO detail section should appear with line items
    await expect(page.getByText('PO #3')).toBeVisible();
    await expect(page.getByText('SKU-001')).toBeVisible();
  });

  test('view PO detail works', async ({ page }) => {
    // Click View on first PO
    const viewButton = page.getByRole('button', { name: 'View' }).first();
    await viewButton.click();

    // PO detail section should appear
    await expect(page.getByText('PO #1')).toBeVisible();

    // Line items table
    await expect(page.getByText('SKU-001')).toBeVisible();
    await expect(page.getByText('Organic Cotton Tee')).toBeVisible();

    // Draft email text area
    await expect(page.getByLabel('Draft Email')).toBeVisible();

    // Send button should be visible
    await expect(page.locator('.grid-btn--primary').filter({ hasText: 'Send to Supplier' })).toBeVisible();
  });

  test('send PO action works', async ({ page }) => {
    // Click View to open a PO first
    const viewButton = page.getByRole('button', { name: 'View' }).first();
    await viewButton.click();

    // Click Send to Supplier
    const sendButton = page.locator('.grid-btn--primary').filter({ hasText: 'Send to Supplier' });
    await sendButton.click();

    // Toast should confirm sending
    await expect(page.getByText('Purchase order sent to supplier')).toBeVisible();
  });

  test('generate draft section has supplier selector', async ({ page }) => {
    // Description text
    await expect(page.locator('.grid-card-desc').filter({ hasText: 'Select a supplier' })).toBeVisible();

    // Select should be present with supplier options — use label selector
    await expect(page.locator('label').getByText('Supplier')).toBeVisible();
  });
});
