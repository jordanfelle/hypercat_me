#!/bin/bash
# Validate and automatically add/update SRI (Subresource Integrity) hashes for CDN assets
# This script ensures all CDN-hosted scripts and stylesheets have integrity attributes
# It will:
# 1. Auto-add missing SRI hashes to CDN resources
# 2. Update existing SRI hashes if they're outdated
# 3. Report any CDN resources that are missing integrity attributes (after attempting fixes)
# 4. Exit with error if validation fails

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

escape_sed_pattern() {
  printf '%s' "$1" | sed -e 's/[\/&]/\\&/g'
}

escape_sed_replacement() {
  printf '%s' "$1" | sed -e 's/[|&\\]/\\&/g'
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
MISSING_COUNT=0
ERROR_URLS=()

for file in $TARGETS; do
  [ -f "$file" ] || continue

  # Skip generated files
  [[ "$file" == */public/* ]] && continue

  # Check if file has CDN script or link tags
  grep -q '\(src\|href\)="https://\(cdnjs\|code\.jquery\|cdn\)\.' "$file" 2>/dev/null || continue

  echo "Processing: $file" >&2

  # Extract src="URL" patterns for scripts
  while IFS= read -r src_url; do
    [ -z "$src_url" ] && continue
    # Skip if not a CDN URL
    [[ "$src_url" =~ ^https://.*\(cdnjs\|code\.jquery\|cdn\) ]] || continue

    echo "  Checking script: $src_url" >&2

    # Compute new hash
    if ! new_hash=$(compute_sri "$src_url" 2>/dev/null); then
      echo "  ⚠ Failed to compute hash for: $src_url" >&2
      ERROR_URLS+=("$src_url")
      ((MISSING_COUNT++))
      continue
    fi

    # Use a different sed delimiter to avoid issues with special chars in URLs
    escaped_url=$(escape_sed_pattern "$src_url")
    replacement_url=$(escape_sed_replacement "$src_url")
    replacement_hash=$(escape_sed_replacement "$new_hash")

    # Check if the line has this src attribute
    if grep -q "src=\"$escaped_url\"" "$file"; then
      # Check if integrity already exists for this URL
      if grep -q "src=\"$escaped_url\".*integrity" "$file"; then
        # Replace existing integrity hash
        sed -i "s|src=\"$escaped_url\"\([^>]*\)integrity=\"sha384-[^\"]*\"|src=\"$replacement_url\"\1integrity=\"sha384-$replacement_hash\"|g" "$file"
        echo "  ✓ Updated hash for script: $src_url" >&2
      else
        # Add integrity attribute after src (before closing > or space)
        sed -i "s|src=\"$escaped_url\"|src=\"$replacement_url\" integrity=\"sha384-$replacement_hash\"|g" "$file"
        echo "  ✓ Added integrity to script: $src_url" >&2
      fi
      ((UPDATE_COUNT++))
    fi
  done < <(grep -oP 'src="\K[^"]+(?=")' "$file" 2>/dev/null | grep -E '(cdnjs|code\.jquery|cdn)' || true)

  # Extract href="URL" patterns for links
  while IFS= read -r href_url; do
    [ -z "$href_url" ] && continue
    # Skip if not a CDN URL
    [[ "$href_url" =~ ^https://.*\(cdnjs\|code\.jquery\|cdn\) ]] || continue

    echo "  Checking link: $href_url" >&2

    # Compute new hash
    if ! new_hash=$(compute_sri "$href_url" 2>/dev/null); then
      echo "  ⚠ Failed to compute hash for: $href_url" >&2
      ERROR_URLS+=("$href_url")
      ((MISSING_COUNT++))
      continue
    fi

    # Escape URL for use in sed
    escaped_url=$(escape_sed_pattern "$href_url")
    replacement_url=$(escape_sed_replacement "$href_url")
    replacement_hash=$(escape_sed_replacement "$new_hash")

    # Check if the line has this href attribute
    if grep -q "href=\"$escaped_url\"" "$file"; then
      # Check if integrity already exists for this URL
      if grep -q "href=\"$escaped_url\".*integrity" "$file"; then
        # Replace existing integrity hash
        sed -i "s|href=\"$escaped_url\"\([^>]*\)integrity=\"sha384-[^\"]*\"|href=\"$replacement_url\"\1integrity=\"sha384-$replacement_hash\"|g" "$file"
        echo "  ✓ Updated hash for link: $href_url" >&2
      else
        # Add integrity attribute after href (before closing > or space)
        sed -i "s|href=\"$escaped_url\"|href=\"$replacement_url\" integrity=\"sha384-$replacement_hash\"|g" "$file"
        echo "  ✓ Added integrity to link: $href_url" >&2
      fi
      ((UPDATE_COUNT++))
    fi
  done < <(grep -oP 'href="\K[^"]+(?=")' "$file" 2>/dev/null | grep -E '(cdnjs|code\.jquery|cdn)' || true)
done

# Validate that all CDN resources have integrity attributes
echo "Validating SRI attributes..." >&2
VALIDATION_FAILED=0
for file in $TARGETS; do
  [ -f "$file" ] || continue
  [[ "$file" == */public/* ]] && continue

  # Find all CDN src= attributes without integrity
  missing_src=$(grep -oP 'src="\K(?!.*integrity)[^"]*(?=")' "$file" 2>/dev/null | grep -E '(cdnjs|code\.jquery|cdn)' || true)
  if [ -n "$missing_src" ]; then
    echo "❌ Missing SRI on script in $file:" >&2
    echo "$missing_src" | while read -r url; do
      echo "  - $url" >&2
    done
    VALIDATION_FAILED=1
  fi

  # Find all CDN href= attributes without integrity
  missing_href=$(grep -oP 'href="\K(?!.*integrity)[^"]*(?=")' "$file" 2>/dev/null | grep -E '(cdnjs|code\.jquery|cdn)' || true)
  if [ -n "$missing_href" ]; then
    echo "❌ Missing SRI on link in $file:" >&2
    echo "$missing_href" | while read -r url; do
      echo "  - $url" >&2
    done
    VALIDATION_FAILED=1
  fi
done

# Clean up stale cache entries (older than 7 days)
find "$CACHE_DIR" -mtime +7 -delete 2>/dev/null || true

# Report results
echo "" >&2
if [ $UPDATE_COUNT -gt 0 ]; then
  echo "✓ Updated/added $UPDATE_COUNT SRI integrity hashes" >&2
fi

if [ $MISSING_COUNT -gt 0 ]; then
  echo "⚠ Failed to generate hashes for $MISSING_COUNT URLs:" >&2
  printf '%s\n' "${ERROR_URLS[@]}" | sort -u >&2
fi

if [ $VALIDATION_FAILED -eq 1 ]; then
  echo "❌ Validation failed: Some CDN resources are missing SRI attributes" >&2
  exit 1
fi

exit 0
