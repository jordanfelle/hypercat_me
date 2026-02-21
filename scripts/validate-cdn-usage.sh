#!/usr/bin/env bash
set -euo pipefail

# Check for disallowed CDN patterns in HTML files
# This hook validates that external JS/CSS libraries don't use known problematic CDNs
# Recommended: Use https://cdnjs.cloudflare.com for external libraries

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONTENT_DIR="${SCRIPT_DIR}/../content"

failures=()

# Verify content directory exists
if [ ! -d "$CONTENT_DIR" ]; then
  echo "❌ Content directory not found: $CONTENT_DIR"
  echo "This script must be run from the repository root or scripts directory."
  exit 1
fi

# CDN patterns to check (excluding cdnjs.cloudflare.com)
DISALLOWED_CDNS=(
  "cdn\\.jsdelivr\\.net"
  "unpkg\\.com"
  "code\\.jquery\\.com"
  "ajax\\.googleapis\\.com"
  "cdnjs\\.com/"  # Match direct https://cdnjs.com/ asset URLs (not cdnjs.cloudflare.com)
  "maxcdn\\.bootstrapcdn\\.com"
  "stackpath\\.bootstrapcdn\\.com"
  "cdn\\.rawgit\\.com"
  "rawgit\\.com"
)

echo "Checking for disallowed CDN usage in HTML files..."

# Find all HTML files (excluding generated/vendored directories)
while IFS= read -r -d '' file; do
  for cdn_pattern in "${DISALLOWED_CDNS[@]}"; do
    if grep -HnEi "(src|href)[[:space:]]*=[[:space:]]*[\"'](https?:)?//${cdn_pattern}" "$file" 2>/dev/null; then
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
  -print0) || true

if (( ${#failures[@]} > 0 )); then
  echo ""
  echo "❌ Found ${#failures[@]} CDN usage violations:"
  for failure in "${failures[@]}"; do
    echo "  - $failure"
  done
  echo ""
  echo "Disallowed CDN patterns detected."
  echo "Recommended: Use https://cdnjs.cloudflare.com for external libraries"
  echo "Find replacements at: https://cdnjs.cloudflare.com/"
  exit 1
fi

echo "✅ No disallowed CDN patterns detected"
exit 0
