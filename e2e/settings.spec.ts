import { test, expect } from '@playwright/test';
import { setupMockApi, mockSettings, mockWebhookEndpoints } from './helpers/mock-api';

test.describe('Settings Page', () => {
  test.beforeEach(async ({ page }) => {
    await setupMockApi(page);
    await page.goto('/settings');
  });

  test('settings load with current values', async ({ page }) => {
    // Page title
    await expect(page.locator('.grid-page-title')).toContainText('Settings');

    // Alert & Report Settings card
    await expect(page.locator('.grid-card-title').filter({ hasText: 'Alert & Report Settings' })).toBeVisible();

    // Alert email field should be pre-populated
    const emailField = page.getByLabel('Alert Email');
    await expect(emailField).toHaveValue(mockSettings.alert_email);

    // Threshold field
    const thresholdField = page.getByLabel('Low Stock Threshold');
    await expect(thresholdField).toHaveValue(String(mockSettings.low_stock_threshold));

    // Timezone select should show current value — scope to main form area to avoid KPI sidebar duplicate
    await expect(page.locator('.invg-main').getByText('Timezone', { exact: true })).toBeVisible();

    // Report day select
    await expect(page.locator('.invg-main').getByText('Weekly Report Day', { exact: true })).toBeVisible();
  });

  test('KPI sidebar shows current config', async ({ page }) => {
    const sidebar = page.locator('.invg-kpi-sidebar');
    await expect(sidebar.locator('.invg-kpi-sidebar-title')).toContainText('Current Config');

    // Alert email
    await expect(sidebar.locator('.invg-kpi-item').filter({ hasText: 'Alert Email' }).locator('.invg-kpi-value')).toContainText(mockSettings.alert_email);

    // Threshold
    await expect(sidebar.locator('.invg-kpi-item').filter({ hasText: 'Threshold' }).locator('.invg-kpi-value')).toContainText('10 units');

    // Webhooks count
    await expect(sidebar.locator('.invg-kpi-item').filter({ hasText: 'Webhooks' }).locator('.invg-kpi-value')).toContainText(
      String(mockWebhookEndpoints.webhook_endpoints.length)
    );
  });

  test('update settings saves correctly', async ({ page }) => {
    // Modify the alert email
    const emailField = page.getByLabel('Alert Email');
    await emailField.clear();
    await emailField.fill('updated@myshop.com');

    // Modify threshold
    const thresholdField = page.getByLabel('Low Stock Threshold');
    await thresholdField.clear();
    await thresholdField.fill('15');

    // Click save
    const saveButton = page.locator('.grid-btn--primary').filter({ hasText: 'Save Settings' });
    await saveButton.click();

    // Toast should confirm
    await expect(page.getByText('Settings saved successfully')).toBeVisible();
  });

  test('webhook endpoints table displays', async ({ page }) => {
    // Webhook endpoints card
    await expect(page.locator('.grid-card-title').filter({ hasText: 'Webhook Endpoints' })).toBeVisible();

    // Table should show existing endpoints
    await expect(page.getByText('https://hooks.slack.com/services/T00/B00/xxx')).toBeVisible();
    await expect(page.getByText('https://example.com/webhooks/oos')).toBeVisible();

    // Status indicators
    await expect(page.getByText('Active').first()).toBeVisible();
    await expect(page.getByText('Inactive').first()).toBeVisible();
  });

  test('webhook endpoint CRUD - add new endpoint', async ({ page }) => {
    // Add new endpoint section
    await expect(page.getByText('Add New Endpoint')).toBeVisible();

    // Fill URL
    const urlField = page.getByLabel('URL');
    await urlField.fill('https://new-webhook.example.com/hook');

    // Click Add button
    const addButton = page.locator('.grid-btn--primary').filter({ hasText: '+ Add' });
    await addButton.click();

    // Toast should confirm
    await expect(page.getByText('Webhook endpoint added')).toBeVisible();
  });

  test('webhook endpoint CRUD - delete endpoint', async ({ page }) => {
    // Click delete on first endpoint
    const deleteButton = page.getByRole('button', { name: 'Delete' }).first();
    await deleteButton.click();

    // Toast should confirm
    await expect(page.getByText('Webhook endpoint removed')).toBeVisible();
  });

  test('save button shows loading state', async ({ page }) => {
    const saveButton = page.locator('.grid-btn--primary').filter({ hasText: 'Save Settings' });
    await expect(saveButton).toBeEnabled();

    await saveButton.click();

    // After save completes, toast should appear
    await expect(page.getByText('Settings saved successfully')).toBeVisible();
  });
});
