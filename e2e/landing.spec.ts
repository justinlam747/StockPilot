import { test, expect } from '@playwright/test';
import { injectShopifyGlobal } from './helpers/mock-api';

test.describe('Landing Page', () => {
  test.beforeEach(async ({ page }) => {
    await injectShopifyGlobal(page);
    await page.goto('/landing');
  });

  test('loads with hero section', async ({ page }) => {
    // Hero title should be visible
    await expect(page.locator('.em-hero__title')).toBeVisible();
    await expect(page.locator('.em-hero__title')).toContainText('Intelligent inventory');

    // Hero subtitle
    await expect(page.locator('.em-hero__subtitle')).toBeVisible();
    await expect(page.locator('.em-hero__subtitle')).toContainText('AI-powered');

    // Section label
    await expect(page.getByText('[ Built for Shopify ]')).toBeVisible();
  });

  test('features section visible', async ({ page }) => {
    const featuresSection = page.locator('#features');
    await expect(featuresSection).toBeVisible();

    // Section label
    await expect(featuresSection.getByText('[ Features ]')).toBeVisible();
    await expect(featuresSection.locator('.em-heading')).toContainText('Everything you need');

    // Feature cards — there should be 6
    const featureCards = page.locator('.em-feature');
    await expect(featureCards).toHaveCount(6);

    // Spot-check specific feature titles
    await expect(featureCards.nth(0).locator('.em-feature__title')).toContainText('Real-time low stock alerts');
    await expect(featureCards.nth(1).locator('.em-feature__title')).toContainText('AI purchase orders');
    await expect(featureCards.nth(2).locator('.em-feature__title')).toContainText('Weekly inventory reports');
  });

  test('CTA buttons present and clickable', async ({ page }) => {
    // Primary CTA in hero
    const heroCta = page.locator('.em-hero__actions .em-btn--dark');
    await expect(heroCta).toBeVisible();
    await expect(heroCta).toContainText('Add to Shopify');
    await expect(heroCta).toHaveAttribute('href', '#install');

    // Final CTA section
    const finalCta = page.locator('#install .em-btn--dark').first();
    await expect(finalCta).toBeVisible();
    await expect(finalCta).toContainText('Add to Shopify');
  });

  test('navigation bar is visible with links', async ({ page }) => {
    const nav = page.locator('.em-nav');
    await expect(nav).toBeVisible();

    // Brand
    await expect(nav.locator('.em-nav__wordmark')).toContainText('Inventory Intelligence');

    // Nav links
    const links = nav.locator('.em-nav__links a');
    await expect(links).toHaveCount(3);
    await expect(links.nth(0)).toContainText('Features');
    await expect(links.nth(1)).toContainText('How it works');
    await expect(links.nth(2)).toContainText('FAQ');

    // Install button in nav
    await expect(nav.locator('.em-btn')).toContainText('Install on Shopify');
  });

  test('how it works section displays steps', async ({ page }) => {
    const section = page.locator('#how-it-works');
    await expect(section).toBeVisible();

    const steps = section.locator('.em-step');
    await expect(steps).toHaveCount(3);

    await expect(steps.nth(0).locator('.em-step__title')).toContainText('Connect your store');
    await expect(steps.nth(1).locator('.em-step__title')).toContainText('Set your rules');
    await expect(steps.nth(2).locator('.em-step__title')).toContainText('Let it run');
  });

  test('open source section visible', async ({ page }) => {
    await expect(page.getByText('Proudly open source.')).toBeVisible();
    await expect(page.getByText('View on GitHub')).toBeVisible();
  });

  test('testimonials section shows merchant quotes', async ({ page }) => {
    const testimonials = page.locator('.em-testimonial');
    await expect(testimonials).toHaveCount(3);

    await expect(testimonials.nth(0).locator('.em-testimonial__name')).toContainText('Sarah Chen');
    await expect(testimonials.nth(1).locator('.em-testimonial__name')).toContainText('Marcus Rivera');
    await expect(testimonials.nth(2).locator('.em-testimonial__name')).toContainText('Anya Patel');
  });

  test('footer is visible with links', async ({ page }) => {
    const footer = page.locator('.em-footer');
    await expect(footer).toBeVisible();

    await expect(footer.locator('.em-footer__brand')).toContainText('Inventory Intelligence');

    const links = footer.locator('.em-footer__right a');
    await expect(links).toHaveCount(4);
  });
});
