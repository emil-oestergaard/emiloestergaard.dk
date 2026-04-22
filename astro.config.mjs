import { defineConfig } from 'astro/config';
import mdx from '@astrojs/mdx';
import sitemap from '@astrojs/sitemap';

export default defineConfig({
  site: 'https://emiloestergaard.dk',
  integrations: [
    mdx(),
    sitemap({
      filter: (page) => !page.includes('/404'),
    }),
  ],
  markdown: {
    shikiConfig: {
      themes: {
        light: 'github-light',
        dark: 'github-dark-dimmed',
      },
      wrap: true,
    },
  },
  build: {
    inlineStylesheets: 'auto',
  },
});
