#!/bin/bash

# Validation script for photo.felle.me links in cons page
# This script is used by the pre-commit "validate-photo-links" hook with `language: script`,
# so it must have the executable bit set or the hook will fail.
# Ensure it is executable with: chmod +x scripts/validate-photo-links.sh
#
# REQUIREMENT: This script requires bash (uses arithmetic expansion ((ERRORS++))).
# The shebang (#!/bin/bash) ensures bash is used when invoked directly.
#
# Note: This script validates URL format only (alphanumeric segments with hyphens, 4-digit years).
# It does NOT verify that photo directories actually exist on photo.felle.me.
# This is intentional - directory existence checks would require HTTP requests and add overhead.
# To fully validate URLs, use: curl -s -o /dev/null -w "%{http_code}" <url>

echo "Validating photo.felle.me links..."

CONS_HTML="content/public/cons/index.html"
ERRORS=0

if [ ! -f "$CONS_HTML" ]; then
    echo "Warning: $CONS_HTML not found. Running hugo build..."
    cd content && npm run build && cd .. || {
        echo "Error: Hugo build failed."
        exit 1
    }
    # Verify the cons HTML file was actually created after build
    if [ ! -f "$CONS_HTML" ]; then
        echo "Error: $CONS_HTML not found after Hugo build. Cannot validate photo links."
        exit 1
    fi
    # Note: Build artifacts (public/ directory) are left in the working directory.
    # This is by design - the pre-commit hook uses these for validation, and they'll
    # be regenerated on the next build. If you want to clean up, run: rm -rf public/
fi

# Extract all photo.felle.me URLs
# Only match valid URL characters (alphanumeric, hyphens, slashes, digits)
LINKS=$(grep -o 'https://photo\.felle\.me/Furries/Cons/[a-zA-Z0-9/_-]*' "$CONS_HTML" | sort -u)

# If no links are found, skip validation to avoid processing an empty string as a link
if [ -z "$LINKS" ]; then
    echo "No photo.felle.me links found in $CONS_HTML"
    exit 0
fi

echo "Found links:"
while IFS= read -r link; do
    # Check URL format: https://photo.felle.me/Furries/Cons/{ConventionName}[/{Year}]

    # Remove the base URL
    path="${link#https://photo.felle.me/Furries/Cons/}"

    # Check if path is empty
    if [ -z "$path" ]; then
        echo "❌ Empty convention name in: $link"
        ((ERRORS++))
        continue
    fi

    # Split path into convention name and year (if present)
    IFS='/' read -r conv_name year <<< "$path"

    # Validate convention name: alphanumeric segments separated by single hyphens
    if ! [[ "$conv_name" =~ ^[a-zA-Z0-9]+(-[a-zA-Z0-9]+)*$ ]]; then
        echo "❌ Invalid convention name format: $conv_name in $link"
        ((ERRORS++))
        continue
    fi

    # If year is present, validate it's a 4-digit number
    if [ -n "$year" ]; then
        if ! [[ "$year" =~ ^[0-9]{4}$ ]]; then
            echo "❌ Invalid year format: $year in $link"
            ((ERRORS++))
            continue
        fi
        echo "✓ Valid: $conv_name / $year"
    else
        echo "✓ Valid: $conv_name (directory)"
    fi
done <<< "$LINKS"

echo ""
if [ $ERRORS -eq 0 ]; then
    echo "✅ All photo links are valid!"
    exit 0
else
    echo "❌ Found $ERRORS validation errors"
    exit 1
fi
