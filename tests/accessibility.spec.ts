import AxeBuilder from '@axe-core/playwright';
import { expect, test } from '@playwright/test';

const PAGES = [
  '/',
  '/about/',
  '/now/',
  '/writing/',
  '/writing/hello-world/',
  '/projects/',
] as const;

test.describe('accessibility (axe-core)', () => {
  for (const path of PAGES) {
    test(`no critical or serious WCAG violations on ${path}`, async ({ page }) => {
      await page.goto(path);

      const results = await new AxeBuilder({ page })
        .withTags(['wcag2a', 'wcag2aa', 'wcag21aa'])
        .analyze();

      const blocking = results.violations.filter(
        (v) => v.impact === 'critical' || v.impact === 'serious',
      );

      const report =
        blocking.length === 0
          ? 'no blocking violations'
          : blocking
              .map(
                (v) =>
                  `  [${v.impact}] ${v.id}: ${v.help}\n    nodes: ${v.nodes.length}\n    ${v.helpUrl}`,
              )
              .join('\n');

      expect(blocking, report).toEqual([]);
    });
  }
});
