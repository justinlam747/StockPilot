import { test, expect } from '@playwright/test';
import { setupMockApi, mockProducts, mockProductsLowStock, mockProductsOutOfStock, mockProductsPage2 } from './helpers/mock-api';

test.describe('Inventory Page', () => {
  test.beforeEach(async ({ page }) => {
    await setupMockApi(page);
    await page.goto('/inventory');
  });

  test('loads with product grid', async ({ page }) => {
    // Page title
    await expect(page.locator('.grid-page-title')).toContainText('Inventory');

    // Product count
    await expect(page.locator('.bento-sync-status').first()).toContainText(`${mockProducts.meta.total_count} products`);

    // Product cards should render
    const productCards = page.locator('.inv-card');
    await expect(productCards).toHaveCount(mockProducts.products.length);

    // Verify product names
    await expect(page.getByText('Organic Cotton Tee')).toBeVisible();
    await expect(page.getByText('Wool Beanie')).toBeVisible();
    await expect(page.getByText('Canvas Tote')).toBeVisible();
  });

  test('filter tabs work - all tab', async ({ page }) => {
    // "All" tab should be selected by default — Polaris Tabs renders <button role="tab">
    const allTab = page.getByRole('tab', { name: 'All' });
    await expect(allTab).toHaveAttribute('aria-selected', 'true');

    // Should show all products
    const productCards = page.locator('.inv-card');
    await expect(productCards).toHaveCount(mockProducts.products.length);
  });

  test('filter tabs work - low stock tab', async ({ page }) => {
    // Click Low Stock tab
    const lowStockTab = page.getByRole('tab', { name: 'Low Stock' });
    await lowStockTab.click();

    // Wait for filtered results
    const productCards = page.locator('.inv-card');
    await expect(productCards).toHaveCount(mockProductsLowStock.products.length);

    // Product count should update
    await expect(page.locator('.bento-sync-status').first()).toContainText(`${mockProductsLowStock.meta.total_count} products`);
  });

  test('filter tabs work - out of stock tab', async ({ page }) => {
    // Click Out of Stock tab
    const outOfStockTab = page.getByRole('tab', { name: 'Out of Stock' });
    await outOfStockTab.click();

    // Wait for filtered results
    const productCards = page.locator('.inv-card');
    await expect(productCards).toHaveCount(mockProductsOutOfStock.products.length);
  });

  test('pagination works', async ({ page }) => {
    // Verify page indicator
    await expect(page.getByText('Page 1 of 3')).toBeVisible();

    // Next page button should be available — Polaris Pagination renders nav with buttons
    const paginationNav = page.locator('.inv-pagination');
    const nextButton = paginationNav.getByRole('button').last();
    await expect(nextButton).toBeEnabled();

    // Click next page
    await nextButton.click();

    // Should show page 2 products
    await expect(page.getByText('Running Shoes')).toBeVisible();
    await expect(page.getByText('Page 2 of 3')).toBeVisible();
  });

  test('density toggle changes grid layout', async ({ page }) => {
    // Density buttons should be visible — use aria-label to find them
    const densityButtons = page.locator('.inv-density-btn');
    await expect(densityButtons).toHaveCount(3);

    // Click 2-column layout (last button = "2 per row")
    const twoColBtn = page.getByRole('button', { name: '2 per row' });
    await twoColBtn.click();
    await expect(twoColBtn).toHaveClass(/inv-density-btn--active/);

    // Grid should have 2-column style applied
    const grid = page.locator('.inv-grid');
    await expect(grid).toHaveAttribute('style', /repeat\(2, 1fr\)/);
  });

  test('product card shows variant count and SKU', async ({ page }) => {
    // Check a product card with multiple variants
    const denimCard = page.locator('.inv-card').filter({ hasText: 'Denim Jacket' });
    await expect(denimCard).toBeVisible();
    await expect(denimCard).toContainText('2 variants');
    await expect(denimCard).toContainText('SKU-004');
  });
});
