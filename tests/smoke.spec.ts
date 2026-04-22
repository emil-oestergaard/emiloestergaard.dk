import { expect, test } from '@playwright/test';

test.describe('critical pages render', () => {
  test('home shows name and recent writing', async ({ page }) => {
    await page.goto('/');
    await expect(page).toHaveTitle(/Emil Østergaard/);
    await expect(page.getByRole('link', { name: 'Emil Østergaard' })).toBeVisible();
    await expect(page.getByText(/Recent writing/i)).toBeVisible();
  });

  test('writing index lists posts', async ({ page }) => {
    await page.goto('/writing/');
    await expect(page.getByRole('heading', { level: 1, name: 'Writing' })).toBeVisible();
    await expect(page.getByRole('link', { name: /Hello, world/ })).toBeVisible();
  });

  test('post page renders content, reading time, and heading anchor', async ({ page }) => {
    await page.goto('/writing/hello-world/');
    await expect(page.getByRole('heading', { level: 1 })).toHaveText('Hello, world');
    await expect(page.getByText(/min read/)).toBeVisible();
    await expect(page.locator('.markdown-alert')).toBeVisible();
    await expect(page.locator('.heading-anchor').first()).toHaveAttribute('href', /^#/);
  });

  test('about page includes structured data', async ({ page }) => {
    await page.goto('/about/');
    await expect(page.getByRole('heading', { level: 1, name: 'About' })).toBeVisible();
    const jsonLd = await page.locator('script[type="application/ld+json"]').textContent();
    expect(jsonLd).toContain('"@type":"Person"');
  });

  test('projects page lists at least one entry', async ({ page }) => {
    await page.goto('/projects/');
    await expect(page.getByRole('heading', { level: 1, name: 'Projects' })).toBeVisible();
    await expect(page.locator('.project-list li').first()).toBeVisible();
  });

  test('404 page responds with 404 and renders', async ({ page }) => {
    const response = await page.goto('/this-route-does-not-exist/');
    expect(response?.status()).toBe(404);
    await expect(page.getByRole('heading', { level: 1, name: '404' })).toBeVisible();
  });
});

test.describe('theme toggle', () => {
  test('switches between dark and light and persists', async ({ page }) => {
    await page.goto('/', { waitUntil: 'networkidle' });
    await page.evaluate(() => window.localStorage.setItem('theme', 'light'));
    await page.reload({ waitUntil: 'networkidle' });

    await expect(page.locator('html')).toHaveAttribute('data-theme', 'light');

    const toggle = page.getByRole('button', { name: /toggle color theme/i });
    await expect(toggle).toBeVisible();

    await expect
      .poll(
        async () => {
          await toggle.click();
          return page.locator('html').getAttribute('data-theme');
        },
        { timeout: 5000, intervals: [100, 250, 500] },
      )
      .toBe('dark');

    expect(await page.evaluate(() => window.localStorage.getItem('theme'))).toBe('dark');

    await page.reload({ waitUntil: 'networkidle' });
    await expect(page.locator('html')).toHaveAttribute('data-theme', 'dark');
  });

  test('persists across client-side navigation (view transitions)', async ({ page }) => {
    await page.goto('/', { waitUntil: 'networkidle' });
    await page.evaluate(() => window.localStorage.setItem('theme', 'dark'));
    await page.reload({ waitUntil: 'networkidle' });
    await expect(page.locator('html')).toHaveAttribute('data-theme', 'dark');

    // Navigate via an in-page link so ClientRouter handles the transition.
    await page.getByRole('link', { name: 'Writing' }).first().click();
    await expect(page).toHaveURL(/\/writing\/?$/);
    await expect(page.locator('html')).toHaveAttribute('data-theme', 'dark');

    await page.getByRole('link', { name: 'About' }).first().click();
    await expect(page).toHaveURL(/\/about\/?$/);
    await expect(page.locator('html')).toHaveAttribute('data-theme', 'dark');
  });
});

test.describe('feed and sitemap', () => {
  test('rss feed is valid xml with a channel', async ({ request }) => {
    const res = await request.get('/rss.xml');
    expect(res.status()).toBe(200);
    expect(res.headers()['content-type']).toMatch(/xml/);
    const body = await res.text();
    expect(body).toContain('<rss');
    expect(body).toContain('<channel>');
  });

  test('sitemap index is present', async ({ request }) => {
    const res = await request.get('/sitemap-index.xml');
    expect(res.status()).toBe(200);
    const body = await res.text();
    expect(body).toContain('<sitemapindex');
  });
});
