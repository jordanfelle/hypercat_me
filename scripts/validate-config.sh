#!/bin/bash

# Configuration validation script
# Validates that all required configuration files are present and properly formatted

set -e

echo "Validating project configuration..."

ERRORS=0

# Function to validate YAML files
validate_yaml() {
    local file="$1"
    if [ ! -f "$file" ]; then
        echo "❌ Missing required file: $file"
        ((ERRORS++))
        return 1
    fi

    # Basic YAML validation - check for invalid indentation patterns
    if grep -P '^\t' "$file" &>/dev/null; then
        echo "❌ $file contains tabs (use spaces for YAML)"
        ((ERRORS++))
        return 1
    fi

    echo "✓ $file is valid"
    return 0
}

# Function to validate TOML files
validate_toml() {
    local file="$1"
    if [ ! -f "$file" ]; then
        echo "❌ Missing required file: $file"
        ((ERRORS++))
        return 1
    fi

    # Basic TOML validation - check for common syntax errors
    if grep -E '^\[.*\[' "$file" &>/dev/null; then
        echo "❌ $file has invalid TOML syntax"
        ((ERRORS++))
        return 1
    fi

    echo "✓ $file is valid"
    return 0
}

# Function to validate JSONC (JSON with comments) files
validate_jsonc() {
    local file="$1"
    if [ ! -f "$file" ]; then
        echo "❌ Missing required file: $file"
        ((ERRORS++))
        return 1
    fi

    # JSONC validation - strip comments and check for valid JSON structure
    # This handles line comments (//), block comments (/* ... */), and inline comments
    if ! python3 - "$file" &>/dev/null << 'PYCODE'
import sys
import json

def strip_jsonc_comments(text: str) -> str:
    result = []
    i = 0
    n = len(text)
    in_string = False
    string_quote = None
    escape = False
    in_line_comment = False
    in_block_comment = False

    while i < n:
        ch = text[i]
        nxt = text[i + 1] if i + 1 < n else ''

        if in_line_comment:
            if ch == '\n':
                in_line_comment = False
                result.append(ch)
            i += 1
            continue

        if in_block_comment:
            if ch == '*' and nxt == '/':
                in_block_comment = False
                i += 2
            else:
                i += 1
            continue

        if in_string:
            result.append(ch)
            if escape:
                escape = False
            elif ch == '\\':
                escape = True
            elif ch == string_quote:
                in_string = False
                string_quote = None
            i += 1
            continue

        if ch == '"':
            in_string = True
            string_quote = ch
            result.append(ch)
            i += 1
            continue

        if ch == '/' and nxt == '/':
            in_line_comment = True
            i += 2
            continue

        if ch == '/' and nxt == '*':
            in_block_comment = True
            i += 2
            continue

        result.append(ch)
        i += 1

    return ''.join(result)

def main() -> int:
    if len(sys.argv) < 2:
        return 1
    path = sys.argv[1]
    try:
        with open(path, 'r', encoding='utf-8') as f:
            text = f.read()
        stripped = strip_jsonc_comments(text)
        json.loads(stripped)
        return 0
    except Exception:
        return 1

if __name__ == "__main__":
    raise SystemExit(main())
PYCODE
    then
        echo "❌ $file has invalid JSON syntax"
        ((ERRORS++))
        return 1
    fi

    echo "✓ $file is valid"
    return 0
}

# Validate Hugo configuration
validate_yaml "content/hugo.yaml" || true

# Validate wrangler configuration
validate_jsonc "wrangler.jsonc" || true

# Validate pre-commit configuration
validate_yaml ".pre-commit-config.yaml" || true

# Check for required directories
required_dirs=(
    "content/content/cons"
    "content/content/sona"
    "content/layouts"
    "content/assets"
)

for dir in "${required_dirs[@]}"; do
    if [ ! -d "$dir" ]; then
        echo "❌ Missing required directory: $dir"
        ((ERRORS++))
    else
        echo "✓ Directory exists: $dir"
    fi
done

echo ""
if [ $ERRORS -eq 0 ]; then
    echo "✅ All configuration files are valid!"
    exit 0
else
    echo "❌ Found $ERRORS validation errors"
    exit 1
fi
