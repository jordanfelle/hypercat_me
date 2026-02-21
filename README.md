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

The workflow creates an empty commit to the main branch, which automatically triggers Cloudflare Pages to rebuild the site. No additional configuration is needed - the workflow uses the standard GitHub token with write permissions to the repository.

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

## External Dependencies

### CDN Usage

When loading external JavaScript and CSS libraries, always use the `https://cdnjs.cloudflare.com` CDN endpoint as the provider. This ensures consistent, reliable, and fast delivery of assets.

**Example:**

```html
<script src="https://cdnjs.cloudflare.com/ajax/libs/jquery/3.6.0/jquery.min.js"></script>
<link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/library/version/style.min.css" />
```

## Scripts

This repository contains scripts in the `scripts/` directory to automate various tasks.

### `rename-poses-images.sh`

This script renumbers all images in the `content/content/poses` subdirectories to be sequential, starting from 1. The renaming process follows a specific order:

1.  It processes directories in the order: `solo`, `duo`, `triple`, then `groups`.
2.  Within each directory, images are sorted by their modification date.

This script is run as a pre-commit hook. There is also a GitHub Action workflow in `.github/workflows/rename-images.yml` that runs this script on pushes to main and commits any changes.

### `convert-images.sh`

This script converts all images (JPG, PNG) in the `content/content/poses` subdirectories to lossless WebP and AVIF formats, and deletes the original files after a successful conversion. It requires `cwebp` and `avifenc` command-line tools to be installed. This script is also run as a pre-commit hook. A GitHub Action workflow in `.github/workflows/convert-images.yml` runs this script on pushes to main and commits any changes.

For local development, you can install the required tools using Homebrew:

```bash
brew install webp aom
```

The GitHub Actions workflow uses `apt-get` to install `webp` and `aom-tools` on the Ubuntu runner.

## License

Content and custom theme copyright Jordan Felle. Hugo is licensed under the Apache License 2.0.
