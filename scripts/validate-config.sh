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

    # Basic JSONC validation - check for common syntax errors
    # Remove comments and check for valid JSON structure
    if ! grep -v '^\s*//' "$file" | python3 -m json.tool &>/dev/null; then
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
