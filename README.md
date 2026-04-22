# emiloestergaard.dk

Personal site. Astro + TypeScript, typography-first design, light/dark themes.

## Commands

| Command         | Action                                     |
| :-------------- | :----------------------------------------- |
| `npm install`   | Install dependencies                       |
| `npm run dev`   | Start dev server at `http://localhost:4321`|
| `npm run build` | Build production site to `./dist/`         |
| `npm run preview` | Preview the production build locally     |
| `npm run check` | Run `astro check` (type + content schema)  |

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

## Deployment

Static output in `./dist/`. Works on Vercel, Netlify, Cloudflare Pages, GitHub
Pages, or any static host — no server runtime required.
