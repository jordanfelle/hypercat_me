#!/bin/bash
# Update SRI (Subresource Integrity) hashes for CDN scripts
# When a CDN script tag's src is updated (e.g., by Renovate), this script
# regenerates the corresponding integrity hash to keep them in sync.
#
# Usage: scripts/update-sri-hashes.sh [files...]
# Or as pre-commit hook: passes all changed HTML files automatically

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

# Cache directory for downloads to avoid redundant requests
CACHE_DIR="${XDG_CACHE_HOME:-.cache}/sri-hashes"
mkdir -p "$CACHE_DIR"

# Compute SRI hash for a given URL
compute_sri() {
  local url="$1"
  local cache_key
  cache_key="$(echo "$url" | sha256sum | cut -d' ' -f1)"
  local cache_file="$CACHE_DIR/$cache_key"

  # Return cached hash if available
  if [ -f "$cache_file" ]; then
    cat "$cache_file"
    return 0
  fi

  # Download script and compute SHA384 hash in base64
  if ! command -v curl &> /dev/null; then
    echo "Error: curl not found" >&2
    return 1
  fi

  local hash
  hash=$(curl -s "$url" | openssl dgst -sha384 -binary | base64 -w0) || return 1
  echo "$hash" > "$cache_file"
  echo "$hash"
}

# Get files to process
if [ $# -eq 0 ]; then
  # If no args, process all HTML files (skip generated/public)
  TARGETS=$(find "$REPO_ROOT" -name "*.html" -type f \
    ! -path "*/public/*" ! -path "*/resources/*" 2>/dev/null || true)
else
  TARGETS="$*"
fi

UPDATE_COUNT=0

for file in $TARGETS; do
  [ -f "$file" ] || continue

  # Skip generated files
  [[ "$file" == */public/* ]] && continue

  # Check if file has CDN script tags
  grep -q 'src="https://\(cdnjs\|code\.jquery\|cdn\)\.' "$file" 2>/dev/null || continue

  # Extract src="URL" patterns and update corresponding integrity attributes
  # Pattern: <script src="https://..." integrity="sha384-OLD_HASH"...>
  while IFS= read -r src_url; do
    # Skip if not a CDN URL
    [[ "$src_url" =~ ^https:// ]] || continue

    # Compute new hash
    new_hash=$(compute_sri "$src_url") || continue

    # Escape URL for use in sed
    escaped_url=$(printf '%s\n' "$src_url" | sed -e 's/[\/&]/\\&/g')

    # Update or add integrity attribute
    if grep -q "src=\"$escaped_url\"" "$file"; then
      # Check if integrity already exists for this URL
      if grep -q "src=\"$escaped_url\".*integrity" "$file"; then
        # Replace existing integrity hash
        sed -i "s/src=\"$escaped_url\"\([^>]*\)integrity=\"sha384-[^\"]*\"/src=\"$escaped_url\"\1integrity=\"sha384-$new_hash\"/g" "$file"
      else
        # Add integrity attribute after src
        sed -i "s/src=\"$escaped_url\"/src=\"$escaped_url\" integrity=\"sha384-$new_hash\"/g" "$file"
      fi
      ((UPDATE_COUNT++))
    fi
  done < <(grep -oP 'src="\K[^"]+(?=")' "$file" || true)

done

# Clean up stale cache entries (older than 7 days)
find "$CACHE_DIR" -mtime +7 -delete 2>/dev/null || true

if [ $UPDATE_COUNT -gt 0 ]; then
  echo "Updated $UPDATE_COUNT SRI integrity hashes"
fi
