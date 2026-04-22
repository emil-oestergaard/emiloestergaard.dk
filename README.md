# emiloestergaard.dk

Personal site. Astro + TypeScript, typography-first design, light/dark themes.

## Commands

| Command                | Action                                      |
| :--------------------- | :------------------------------------------ |
| `npm install`          | Install dependencies                        |
| `npm run dev`          | Start dev server at `http://localhost:4321` |
| `npm run build`        | Build production site to `./dist/`          |
| `npm run preview`      | Preview the production build locally        |
| `npm run check`        | Run `astro check` (type + content schema)   |
| `npm run lint`         | Run ESLint (TypeScript + Astro rules)       |
| `npm run format`       | Format all files with Prettier              |
| `npm run format:check` | Verify formatting without writing           |
| `npm run test`         | Run Playwright smoke tests (builds first)   |
| `npm run test:lh`      | Run Lighthouse CI against built output\*    |

\*Lighthouse CI runs cleanly on Linux (CI). On Windows it may fail during
Chrome cleanup due to a known `chrome-launcher` EPERM bug; the audit itself
completes, but local reports may not land. Rely on CI for the authoritative
run.

## Structure

```
src/
├── components/    # SiteHeader, SiteFooter, ThemeToggle
├── content/
│   ├── writing/   # Essays and notes (.md / .mdx)
│   └── projects/  # Project entries (.md / .mdx)
├── layouts/       # BaseLayout, ProseLayout
├── pages/         # Routes
├── styles/        # tokens.css, global.css
└── content.config.ts  # Collection schemas
```

## Authoring

**Writing** — add a file to `src/content/writing/`:

```md
---
title: 'Post title'
description: 'One-sentence summary.'
pubDate: 2026-04-22
tags: ['optional', 'tags']
draft: false
---

Body in Markdown or MDX.
```

**Projects** — add a file to `src/content/projects/`:

```md
---
title: 'Project name'
description: 'One-sentence summary.'
year: 2026
role: 'Your role'
link: 'https://example.com'
repo: 'https://github.com/...'
order: 1
---
```

Schemas live in `src/content.config.ts`. Invalid frontmatter fails the build.

## Quality gates

Every push and PR runs three parallel jobs in `.github/workflows/ci.yml`:

1. **Build** — lint, format check, type check, production build
2. **E2E** — Playwright smoke tests against the built site (chromium)
3. **Lighthouse CI** — Performance/a11y/best-practices/SEO ≥ 95 on every page

## Deployment

Static output in `./dist/`. Works on Vercel, Netlify, Cloudflare Pages, GitHub
Pages, or any static host — no server runtime required.
