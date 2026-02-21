#!/usr/bin/env bash

# Validate that external JS/CSS libraries use cdnjs.cloudflare.com
# This hook checks for common CDN patterns and ensures consistency

set -e

ERRORS=0

# CDN patterns to check (excluding cdnjs.cloudflare.com)
DISALLOWED_CDNS=(
  "cdn.jsdelivr.net"
  "unpkg.com"
  "code.jquery.com"
  "ajax.googleapis.com"
  "cdnjs.com[^/]"  # Match cdnjs.com but not cdnjs.cloudflare.com
  "maxcdn.bootstrapcdn.com"
  "stackpath.bootstrapcdn.com"
  "cdn.rawgit.com"
  "rawgit.com"
)

echo "Checking for non-cdnjs CDN usage in HTML files..."

# Find all HTML files (excluding generated/vendored directories)
while IFS= read -r -d '' file; do
  for cdn_pattern in "${DISALLOWED_CDNS[@]}"; do
    if grep -HnE "(src|href)=[\"']https?://${cdn_pattern}" "$file" 2>/dev/null; then
      echo "❌ ERROR: File '$file' uses disallowed CDN: $cdn_pattern"
      echo "   Please use cdnjs.cloudflare.com instead"
      echo "   Example: https://cdnjs.cloudflare.com/ajax/libs/library/version/file.js"
      ERRORS=$((ERRORS + 1))
    fi
  done
done < <(find . -type f \( -name "*.html" -o -name "*.htm" \) \
  ! -path "*/node_modules/*" \
  ! -path "*/public/*" \
  ! -path "*/resources/*" \
  ! -path "*/.git/*" \
  ! -path "*/vendor/*" \
  ! -path "*/dist/*" \
  -print0)

if [ $ERRORS -gt 0 ]; then
  echo ""
  echo "❌ Found $ERRORS CDN usage violations"
  echo "All external libraries must use cdnjs.cloudflare.com"
  echo ""
  echo "Find replacements at: https://cdnjs.cloudflare.com/"
  exit 1
fi

echo "✅ All CDN usage is compliant with cdnjs.cloudflare.com"
exit 0
