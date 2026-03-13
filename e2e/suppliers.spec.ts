import { test, expect } from '@playwright/test';
import { setupMockApi, mockSuppliers } from './helpers/mock-api';

test.describe('Suppliers Page', () => {
  test.beforeEach(async ({ page }) => {
    await setupMockApi(page);
    await page.goto('/suppliers');
  });

  test('supplier list loads', async ({ page }) => {
    // Page title
    await expect(page.locator('.grid-page-title')).toContainText('Suppliers');

    // Supplier directory title
    await expect(page.locator('.grid-card-title').filter({ hasText: 'Supplier Directory' })).toBeVisible();

    // DataTable should render with supplier data — find the table element inside the grid card
    const table = page.locator('.grid-card').filter({ hasText: 'Supplier Directory' }).locator('table');
    await expect(table).toBeVisible();

    // Verify supplier names from mock data — scope to table to avoid KPI sidebar duplicate
    const directory = page.locator('.grid-card').filter({ hasText: 'Supplier Directory' });
    await expect(directory.getByText('Textile Co.')).toBeVisible();
    await expect(directory.getByText('WoolWorks Ltd')).toBeVisible();
    await expect(directory.getByRole('rowheader', { name: 'PackagePro' })).toBeVisible();

    // Verify emails
    await expect(page.getByText('orders@textileco.com')).toBeVisible();

    // KPI sidebar
    await expect(page.locator('.invg-kpi-sidebar-title')).toContainText('Overview');
    await expect(page.locator('.invg-kpi-value').filter({ hasText: String(mockSuppliers.suppliers.length) })).toBeVisible();
  });

  test('create supplier modal works', async ({ page }) => {
    // Click add supplier button
    const addButton = page.locator('.grid-btn--primary').filter({ hasText: 'Add Supplier' });
    await expect(addButton).toBeVisible();
    await addButton.click();

    // Modal should open with "Add Supplier" title — Polaris Modal uses role="dialog"
    const modal = page.getByRole('dialog');
    await expect(modal).toBeVisible();
    await expect(modal).toContainText('Add Supplier');

    // Fill form fields — use exact role to avoid matching "Contact Name"
    const nameField = modal.getByRole('textbox', { name: 'Name', exact: true });
    await nameField.clear();
    await nameField.fill('New Fabric Co.');

    const emailField = modal.getByLabel('Email');
    await emailField.fill('info@newfabric.com');

    const contactField = modal.getByLabel('Contact Name');
    await contactField.fill('Alice Johnson');

    const leadTimeField = modal.getByLabel('Lead Time (days)');
    await leadTimeField.clear();
    await leadTimeField.fill('10');

    // Click Save
    const saveButton = modal.getByRole('button', { name: 'Save' });
    await saveButton.click();

    // Modal should close
    await expect(modal).not.toBeVisible();

    // Toast should confirm creation
    await expect(page.getByText('Supplier added')).toBeVisible();
  });

  test('edit supplier works', async ({ page }) => {
    // Click Edit on first supplier
    const editButton = page.getByRole('button', { name: 'Edit' }).first();
    await editButton.click();

    // Modal should open with "Edit Supplier" title — Polaris Modal uses role="dialog"
    const modal = page.getByRole('dialog');
    await expect(modal).toBeVisible();
    await expect(modal).toContainText('Edit Supplier');

    // Name field should be pre-populated — use exact role to avoid matching "Contact Name"
    const nameField = modal.getByRole('textbox', { name: 'Name', exact: true });
    await expect(nameField).toHaveValue('Textile Co.');

    // Modify the name
    await nameField.clear();
    await nameField.fill('Textile Co. International');

    // Save
    const saveButton = modal.getByRole('button', { name: 'Save' });
    await saveButton.click();

    // Modal should close
    await expect(modal).not.toBeVisible();

    // Toast
    await expect(page.getByText('Supplier updated')).toBeVisible();
  });

  test('delete supplier with confirmation', async ({ page }) => {
    // Click Delete on first supplier
    const deleteButton = page.getByRole('button', { name: 'Delete' }).first();
    await deleteButton.click();

    // Toast should confirm deletion
    await expect(page.getByText('Supplier deleted')).toBeVisible();
  });

  test('KPI sidebar shows correct metrics', async ({ page }) => {
    const sidebar = page.locator('.invg-kpi-sidebar');
    await expect(sidebar).toBeVisible();

    // Supplier count
    await expect(sidebar.locator('.invg-kpi-item').filter({ hasText: 'Suppliers' }).locator('.invg-kpi-value')).toContainText('3');

    // Avg lead time (7+14+21)/3 = 14
    await expect(sidebar.locator('.invg-kpi-item').filter({ hasText: 'Avg Lead Time' }).locator('.invg-kpi-value')).toContainText('14d');

    // Fastest supplier
    await expect(sidebar.locator('.invg-kpi-item').filter({ hasText: 'Fastest' }).locator('.invg-kpi-value')).toContainText('Textile Co.');
  });

  test('lead time indicators display correctly', async ({ page }) => {
    // Lead time dots should be visible
    const leadTimes = page.locator('.lead-time');
    await expect(leadTimes).toHaveCount(3);

    // Check that days are displayed
    await expect(leadTimes.nth(0)).toContainText('7 days');
    await expect(leadTimes.nth(1)).toContainText('14 days');
    await expect(leadTimes.nth(2)).toContainText('21 days');
  });
});
