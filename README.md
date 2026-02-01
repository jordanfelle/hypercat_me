# hypercat.me

Personal website built with Hugo and the Hypercat theme.

## Features

- **Static Site Generation**: Built with Hugo for fast, secure static site hosting
- **Custom Theme**: Uses the custom Hypercat theme
- **Cloudflare Integration**: Deployed to Cloudflare Pages via Wrangler

## Setup

### Prerequisites

- Hugo (extended version)
- Node.js (for Wrangler)

### Local Development

Run the Hugo development server:

```bash
hugo server --disableFastRender
```

The site will be available at `http://localhost:1313`.

### Building

Build the site for production:

```bash
hugo --minify
```

This generates the static site in the `public/` directory.

## Deployment

The site is deployed to Cloudflare Pages using Wrangler. Configuration is in [`wrangler.jsonc`](wrangler.jsonc).

### Automatic Deployment

Deployments are handled automatically by Cloudflare Pages when changes are pushed to the configured branch. The build step uses the settings from [`wrangler.jsonc`](wrangler.jsonc), running `hugo --minify` to build the site.

### Scheduled Monthly Rebuilds

The site is automatically rebuilt on the 1st of each month using a GitHub Actions workflow ([`.github/workflows/monthly-rebuild.yml`](.github/workflows/monthly-rebuild.yml)). This ensures that dynamic content (like age calculations) stays up-to-date.

To enable this workflow, you need to configure a GitHub secret:

1. In your Cloudflare Pages project, go to Settings > Builds & deployments
2. Find and copy your Build Hook URL (create one if it doesn't exist)
3. In your GitHub repository, go to Settings > Secrets and variables > Actions
4. Create a new repository secret named `CLOUDFLARE_PAGES_BUILD_WEBHOOK` with the Build Hook URL as its value

The workflow can also be triggered manually from the Actions tab for testing purposes.

## Project Structure

```
hypercat_me/
├── archetypes/         # Content templates
├── assets/             # CSS and other assets
├── content/            # Site content (Markdown files)
├── layouts/            # Custom layout templates
├── static/             # Static files (images, fonts, etc.)
├── themes/             # Hugo themes
│   └── hypercat-theme/ # Custom Hypercat theme
├── hugo.yaml           # Hugo configuration
├── wrangler.jsonc      # Cloudflare Pages deployment configuration
└── renovate.json       # Dependency update configuration
```

## Pre-commit Hooks

This repository uses pre-commit hooks to maintain code quality. See [PRE_COMMIT_SETUP.md](PRE_COMMIT_SETUP.md) for installation and usage instructions.

## License

Content and custom theme copyright Jordan Felle. Hugo is licensed under the Apache License 2.0.
