#!/usr/bin/env bash
set -euo pipefail

# Validate that external JS/CSS libraries use cdnjs.cloudflare.com
# This hook checks for common CDN patterns and ensures consistency

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONTENT_DIR="${SCRIPT_DIR}/../content"

failures=()

# CDN patterns to check (excluding cdnjs.cloudflare.com)
DISALLOWED_CDNS=(
  "cdn.jsdelivr.net"
  "unpkg.com"
  "code.jquery.com"
  "ajax.googleapis.com"
  "://cdnjs\.com/"  # Match direct cdnjs.com URLs but not cdnjs.cloudflare.com
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
      failures+=("$file: uses disallowed CDN: $cdn_pattern")
    fi
  done
done < <(find "$CONTENT_DIR" -type f \( -name "*.html" -o -name "*.htm" \) \
  ! -path "*/node_modules/*" \
  ! -path "*/public/*" \
  ! -path "*/resources/*" \
  ! -path "*/.git/*" \
  ! -path "*/vendor/*" \
  ! -path "*/dist/*" \
  -print0)

if (( ${#failures[@]} > 0 )); then
  echo ""
  echo "❌ Found ${#failures[@]} CDN usage violations:"
  for failure in "${failures[@]}"; do
    echo "  - $failure"
  done
  echo ""
  echo "All external libraries must use cdnjs.cloudflare.com"
  echo "Find replacements at: https://cdnjs.cloudflare.com/"
  exit 1
fi

echo "✅ All CDN usage is compliant with cdnjs.cloudflare.com"
exit 0
