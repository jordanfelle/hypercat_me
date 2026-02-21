# Copilot Instructions for hypercat_me

## Repository Overview

**hypercat_me** is a static website built with Hugo (v0.156.0+) using the PaperMod theme. It's a small personal portfolio/profile site (37 pages) showcasing a furry character's sona reference sheets and convention information. The site is approximately 66MB when built, with most content being optimized images.

**Tech Stack:**

- Static Site Generator: Hugo v0.156.0+ (extended version required)
- Theme: hypercat-theme (customized PaperMod theme, included in repository)
- Languages: Hugo templates (.html), Markdown (.md), YAML configuration
- No backend, no Node.js, no Python - pure Hugo site

## Critical Setup Requirements

### 1. Theme (INCLUDED)

The theme is a customized version of PaperMod located at `themes/hypercat-theme/`. It is **not a git submodule** and is included directly in the repository, so no special initialization is required.

## Hugo Installation

Install Hugo v0.156.0 or higher (extended version):

```bash
# Example for Linux (check hugo.io for other platforms):
wget https://github.com/gohugoio/hugo/releases/download/v0.156.0/hugo_extended_0.156.0_linux-amd64.tar.gz
tar -xzf hugo_extended_0.156.0_linux-amd64.tar.gz
sudo mv hugo /usr/local/bin/
hugo version  # Verify: hugo v0.156.0+extended
```

The extended version is required for SCSS/SASS processing. See https://gohugo.io/installation/ for other platforms.

## Build and Development Commands

### Build Site (Production)

```bash
hugo
```

- Takes ~10-11 seconds (first build or clean build)
- Takes ~50-100ms (incremental builds)
- Output directory: `public/`
- Processes 21 images, generates 37 pages
- **Note:** Minified builds (`hugo --minify`) may encounter JSON errors in some cons pages. This is a known issue with certain content files and does not affect basic builds.

### Development Server

```bash
hugo server
# Or bind to all interfaces:
hugo server --bind 0.0.0.0
```

- Starts in ~50-60ms after initial build
- Available at: http://localhost:1313/
- Auto-reloads on file changes
- Fast Render Mode enabled by default
- Press Ctrl+C to stop

### Clean Build

```bash
rm -rf public/ resources/_gen/ .hugo_build.lock
hugo
```

Clean these artifacts when:

- Switching branches with significant changes
- Theme updates
- Unexpected rendering issues

## Repository Structure

```
├── .github/
│   ├── copilot-instructions.md  # Copilot instructions for this repo
│   └── workflows/               # GitHub Actions (image optimization)
├── archetypes/
│   └── default.md               # Template for new content
├── assets/
│   ├── css/extended/            # Custom CSS overrides
│   └── images/                  # Source images (sona refs, profile)
├── content/                     # All site content (Markdown)
│   ├── cons/                    # Convention information
│   └── sona/                    # Sona reference sheets
│       ├── sfw.md
│       └── nsfw/
├── layouts/
│   └── shortcodes/
│       └── myAge.html           # Custom shortcode for age calculation
├── static/                      # Static files (favicons, icons)
├── themes/
│   └── hypercat-theme/          # Customized PaperMod theme (included in repo)
├── hugo.yaml                    # Main configuration file
├── .gitignore
└── README.md
```

**Generated directories (gitignored):**

- `public/` - Built site output
- `resources/_gen/` - Generated resources cache
- `.hugo_build.lock` - Build lock file

## Configuration Details

- **Main config:** `hugo.yaml` (159 lines)
- **Theme:** hypercat-theme (customized PaperMod - see `themes/hypercat-theme/README.md`)
- **Base URL:** https://hypercat.me/
- **Profile mode:** Enabled with custom image and social links
- **Custom shortcode:** `{{< myAge >}}` - calculates age from birthdate (1988-11-02)

## GitHub Actions / CI

### Image Optimization Workflow

Two workflows automatically optimize images:

1. **image-optimizer.yml** - Runs on PRs when image files change
2. **image-optimizer-manual.yml** - Manual workflow dispatch

These use `cadamsdev/image-optimizer-action` to compress image files (PNG, JPG, JPEG, GIF, SVG, WEBP, AVIF). Check `.github/workflows/` for current action versions.

**No other CI/CD checks** - no tests, no linting, no build validation in CI.

## Common Operations

### Creating New Content

```bash
hugo new content/section/page-name.md
```

Uses archetype from `archetypes/default.md` with front matter:

- date (auto-generated)
- draft: true
- title (auto-generated from filename)

### Listing All Content

```bash
hugo list all
```

Shows all pages with path, slug, title, dates, draft status, permalink.

### View Configuration

```bash
hugo config
```

### Environment Info

```bash
hugo env
```

Shows Hugo version, Go version, libsass version, libwebp version.

## Making Code Changes

### Content Changes (Markdown)

- Edit files in `content/` directory
- Use front matter (YAML between `---`)
- Rebuild or let dev server auto-reload
- **No tests to run** - just verify in browser

### Layout/Template Changes

- Custom layouts in `layouts/` directory
- Override theme templates by matching theme structure
- Current custom: `layouts/shortcodes/myAge.html`

### Style Changes

- Custom CSS in `assets/css/extended/`
- Current: `profile.css` (removes border-radius from profile images)
- Hugo processes and minifies CSS automatically

### Configuration Changes

- Edit `hugo.yaml`
- Full rebuild recommended after config changes
- Validate with `hugo config`

## Known Issues and Gotchas

1. **Minify Build Errors**

   - Symptoms: JSON parsing errors in cons pages when using `hugo --minify`
   - Impact: Basic `hugo` command works fine, but minified builds fail
   - Workaround: Use basic `hugo` command without `--minify` flag

2. **First Build is Slow**

   - First/clean build: ~10 seconds (image processing)
   - Incremental builds: ~50-100ms
   - Server startup adds ~50-70ms to initial build

3. **No Validation in CI**

   - Only image optimization runs in CI
   - Build validation must be done locally
   - Always test `hugo` command succeeds before committing

4. **Theme is Included in Repository**
   - Theme is at `themes/hypercat-theme/` (not a submodule)
   - Safe to customize theme files directly if needed
   - Theme is based on PaperMod - see README for documentation

## Validation Checklist

Before finalizing changes:

1. ✅ Clean build succeeds: `rm -rf public/ && hugo`
2. ✅ Check for warnings in output (none expected with current setup)
3. ✅ Test dev server: `hugo server` and visit http://localhost:1313
4. ✅ Verify changes render correctly in browser
5. ✅ Check that no secrets or sensitive content added
6. ✅ Ensure `.gitignore` excludes `public/`, `resources/_gen/`, `.hugo_build.lock`

## Quick Reference

| Task         | Command                                                   | Time                                |
| ------------ | --------------------------------------------------------- | ----------------------------------- |
| Install Hugo | See "Hugo Installation" section                           | 10-30s                              |
| Build site   | `hugo`                                                    | 10s (clean), 50-100ms (incremental) |
| Dev server   | `hugo server`                                             | Starts in 50-70ms                   |
| Clean build  | `rm -rf public/ resources/_gen/ .hugo_build.lock && hugo` | 10s                                 |
| List content | `hugo list all`                                           | <1s                                 |
| View config  | `hugo config`                                             | <1s                                 |

## Trust These Instructions

These instructions have been validated through:

- Clean repository clone and build testing
- Multiple build and clean cycles
- Development server testing
- Configuration verification
- Hugo v0.156.0 extended edition validation

**Only search for additional information if:**

- These instructions appear outdated (check Hugo version)
- You encounter errors not documented here
- You need to understand hypercat-theme/PaperMod theme specifics

For theme documentation, see `themes/hypercat-theme/README.md`.
