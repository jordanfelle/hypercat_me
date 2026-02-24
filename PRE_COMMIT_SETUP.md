# Pre-commit Hooks Setup

This repository uses pre-commit hooks to maintain code quality and consistency.

## Prerequisites

Before installing pre-commit hooks, ensure you have:

- **Python 3.8+** - Required for pre-commit itself
- **Node.js 20.19+** - Required for markdownlint, Prettier, and stylelint tooling
- **FFmpeg** - Required for poses image dimension validation
  - macOS: `brew install ffmpeg`
  - Ubuntu/Debian: `sudo apt install ffmpeg`
- **Hugo extended** - Required for the Hugo build check hook (see [Hugo installation](https://gohugo.io/installation/))
  - Minimum version: v0.146.0 (as specified in the theme)
  - Must be available on your PATH (verify with `hugo version`)
- **Stylelint** - Required for CSS linting (installed via npm)
  - Install: `npm install` (from the repo root)

## Installation

1. Install `pre-commit`:

   ```bash
   pip install pre-commit
   ```

2. Install npm dependencies (required for stylelint):

   ```bash
   npm install
   ```

3. Install the git hooks:

   ```bash
   pre-commit install
   pre-commit install --hook-type pre-push
   ```

4. (Optional) Run all hooks on all files to check the current state:
   ```bash
   pre-commit run --all-files
   ```

## What Checks Are Included

- **Trailing whitespace**: Removes trailing whitespace from files
- **End of file fixer**: Ensures files end with a newline
- **YAML checker**: Validates YAML syntax in `.yml`/`.yaml` files (e.g., GitHub Actions workflows and other YAML config files)
- **JSON checker**: Validates JSON syntax
- **TOML checker**: Validates TOML syntax
- **Merge conflict checker**: Detects merge conflict markers
- **Case conflict checker**: Detects case conflicts in filenames
- **Executable shebangs**: Ensures shell scripts have shebangs
- **Mixed line endings**: Fixes mixed line endings (converts to LF)
- **YAML linting**: Checks YAML style and formatting
- **Markdown linting**: Checks markdown formatting and consistency
- **Prettier**: Auto-formats markdown and JSON files
- **Codespell**: Checks for common spelling mistakes
- **GitHub Actions workflow validation**: Validates workflow YAML syntax and configurations
- **Shell script linting**: Validates bash/shell scripts with shellcheck
- **Stylelint**: Lints CSS files for syntax errors and best practices
- **SRI integrity validation**: Validates and automatically adds/updates Subresource Integrity hashes for CDN-hosted scripts and stylesheets
- **Poses image auto-resizing**: Automatically resizes images in `content/content/poses/` to ≤2000px on long edge while preserving aspect ratio
- **Hugo build check**: Verifies the site builds successfully
- **Photo links validation**: Validates all photo.felle.me links follow the correct format (runs after Hugo build)

## Consistency Note

Keep build tooling, SRI scripts, and CI workflow patterns aligned across the
`hypercat_me`, `felle_me`, and `shutterpaws_pics` repos whenever possible.

The GitHub Actions workflow (`.github/workflows/pre-commit.yml`) pins specific versions for reproducibility. **Version updates are handled automatically by Renovate**, which is configured in `renovate.json`. Renovate will:

- Monitor for new Hugo, Node.js, and other dependency releases
- Create PRs automatically when updates are available
- Run the pre-commit checks against new versions to ensure compatibility
- Notify you of any breaking changes

This ensures you get security updates and new features automatically without manual version bumping.

## Manual Usage

To run pre-commit checks:

```bash
# Run on staged files only
pre-commit run

# Run on all files
pre-commit run --all-files

# Run a specific hook
pre-commit run yamllint --all-files
pre-commit run markdownlint --all-files

# Update hooks to latest versions
pre-commit autoupdate
```

## Configuration Files

- `.pre-commit-config.yaml` - Main pre-commit configuration
- `.markdownlint.json` - Markdown linting rules
- `.prettierrc` - Prettier formatting rules
- `.codespellrc` - Codespell configuration

## Troubleshooting

If a hook fails:

1. Review the error message
2. Fix the issues manually or let auto-fixing hooks correct them
3. Stage the fixed files
4. Commit again

Some hooks (like `trailing-whitespace` and `end-of-file-fixer`) automatically fix issues, while others (like `markdownlint` and `hugo-build`) require manual intervention.

### Poses Image Auto-Resizing

The poses image hook automatically resizes any images in `content/content/poses/` that exceed 2000px on the long edge. This is the primary validation point - images get fixed locally before being committed.

When the hook detects oversized images:

1. Images are resized proportionally to fit within 2000px on the longest dimension
2. The hook writes the resized images back to disk (but does not stage them)
3. You'll see messages like: `⚙️  Resizing solo/001.jpg: 3000x2000 → max long edge 2000`

After the hook runs, the commit will be stopped so you can review the changes. To continue:

1. Review the resized images with `git diff`
2. Stage them with `git add`
3. Re-run `git commit` (which will re-run `pre-commit` and complete if everything passes)

### Hugo Build Failures

If the Hugo build check fails, it means there's a syntax error or configuration issue in your content or theme. Run `hugo` locally to see detailed error messages:

```bash
hugo  # or hugo server for development
```

Common issues:

- Invalid YAML frontmatter in content files
- Broken template syntax
- Missing required fields in front matter
