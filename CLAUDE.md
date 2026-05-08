# soup-blog

Hexo blog deployed to Cloudflare Pages (Direct Upload mode).

## Deploy

```bash
./deploy.sh
```

Or single command:
```bash
CLOUDFLARE_API_TOKEN=cfut_xxx npx wrangler pages deploy public/ --project-name soup-blog --branch main
```

- Token stored in `.cf_token` (gitignored), or set `CLOUDFLARE_API_TOKEN` env var
- CF Pages project: `soup-blog` | Account: `bbc11b448363fa5de8adfd60866728a9`
- Domain: https://blog.soooup.org | Preview: https://soup-blog.pages.dev
- **Git push does NOT auto-deploy** — this is Direct Upload, not Git integration

## Theme

hexo-theme-maoblog (git submodule at `themes/maoblog/`)

### Dark code blocks

Custom CSS in `source/css/prism.css` overrides the theme's default light theme.
Highlighter is `prismjs` (set in `_config.yml`).

## Post format

```yaml
---
title: Title here
date: 2026-05-08 18:00:00
tags: [tag1, tag2]
---
```
