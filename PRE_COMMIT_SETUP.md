# Pre-commit Hooks Setup

This repository uses pre-commit hooks to maintain code quality and consistency.

## Installation

1. Install `pre-commit`:

   ```bash
   pip install pre-commit
   ```

2. Install the git hooks:

   ```bash
   pre-commit install
   ```

3. (Optional) Run all hooks on all files to check the current state:
   ```bash
   pre-commit run --all-files
   ```

## What Checks Are Included

- **Trailing whitespace**: Removes trailing whitespace from files
- **End of file fixer**: Ensures files end with a newline
- **YAML checker**: Validates YAML syntax (hugo.yaml, front matter)
- **JSON checker**: Validates JSON syntax
- **TOML checker**: Validates TOML syntax
- **Merge conflict checker**: Detects merge conflict markers
- **YAML linting**: Checks YAML style and formatting
- **Markdown linting**: Checks markdown formatting and consistency
- **Prettier**: Auto-formats markdown and JSON files
- **Codespell**: Checks for common spelling mistakes
- **GitHub Actions workflow validation**: Validates workflow YAML syntax and configurations
- **Hugo build check**: Verifies the site builds successfully

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
- `.mlc_config.json` - Markdown link checker configuration
- `.codespellrc` - Codespell configuration

## Troubleshooting

If a hook fails:

1. Review the error message
2. Fix the issues manually or let auto-fixing hooks correct them
3. Stage the fixed files
4. Commit again

Some hooks (like `trailing-whitespace` and `end-of-file-fixer`) automatically fix issues, while others (like `markdownlint` and `hugo-build`) require manual intervention.

### Hugo Build Failures

If the Hugo build check fails, it means there's a syntax error or configuration issue in your content or theme. Run `hugo` locally to see detailed error messages:

```bash
hugo  # or hugo server for development
```

Common issues:

- Invalid YAML frontmatter in content files
- Broken template syntax
- Missing required fields in front matter
