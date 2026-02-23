#!/usr/bin/env bash
# Update SRI (Subresource Integrity) hashes for CDN scripts and stylesheets
# When a CDN script or stylesheet tag's src/href is updated (e.g., by Renovate), this script
# regenerates the corresponding integrity hash to keep them in sync.
#
# Usage: scripts/update-sri-hashes.sh [files...]
# Or as pre-commit hook: passes all changed HTML files automatically
# Note: pre-commit uses scripts/validate-and-update-sri.sh; this script is intended for manual runs.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

# Cache directory for downloads to avoid redundant requests
if [ -n "${XDG_CACHE_HOME-}" ]; then
  CACHE_DIR="${XDG_CACHE_HOME%/}/sri-hashes"
else
  CACHE_DIR="$REPO_ROOT/.cache/sri-hashes"
fi
if ! mkdir -p "$CACHE_DIR"; then
  echo "Error: failed to create cache directory '$CACHE_DIR'" >&2
  exit 1
fi

sha256_key() {
  if command -v sha256sum >/dev/null 2>&1; then
    printf '%s' "$1" | sha256sum | awk '{print $1}'
    return 0
  fi
  if command -v shasum >/dev/null 2>&1; then
    printf '%s' "$1" | shasum -a 256 | awk '{print $1}'
    return 0
  fi
  echo "Error: neither sha256sum nor shasum is available" >&2
  return 1
}

base64_no_wrap() {
  if base64 -w0 </dev/null >/dev/null 2>&1; then
    base64 -w0
  else
    base64 | tr -d '\n'
  fi
}

# Compute SRI hash for a given URL
compute_sri() {
  local url="$1"
  local cache_key
  cache_key="$(sha256_key "$url")" || return 1
  local cache_file="$CACHE_DIR/$cache_key"

  # Return cached hash if available
  if [ -f "$cache_file" ]; then
    cat "$cache_file"
    return 0
  fi

  # Check dependencies
  if ! command -v curl &> /dev/null; then
    echo "Error: curl not found" >&2
    return 1
  fi
  if ! command -v openssl &> /dev/null; then
    echo "Error: openssl not found" >&2
    return 1
  fi
  if ! command -v base64 &> /dev/null; then
    echo "Error: base64 not found" >&2
    return 1
  fi

  local hash
  if ! hash=$(curl -fsSL "$url" | openssl dgst -sha384 -binary | base64_no_wrap); then
    echo "Error: failed to download or hash '$url'" >&2
    return 1
  fi
  echo "$hash" > "$cache_file"
  echo "$hash"
}

escape_sed_pattern() {
  printf '%s' "$1" | sed -e 's/[][(){}.^$*+?|]/\\&/g' -e 's/[\/&]/\\&/g'
}

escape_sed_replacement() {
  printf '%s' "$1" | sed -e 's/[|&\\]/\\&/g'
}

sed_in_place() {
  local expr="$1"
  local file="$2"
  if sed --version >/dev/null 2>&1; then
    sed -i "$expr" "$file"
  else
    sed -i '' "$expr" "$file"
  fi
}

# Get files to process
TARGETS=()
if [ $# -eq 0 ]; then
  # If no args, process all HTML files (skip generated/public)
  while IFS= read -r -d '' file; do
    TARGETS+=("$file")
  done < <(find "$REPO_ROOT" -name "*.html" -type f \
    ! -path "*/public/*" ! -path "*/resources/*" -print0 2>/dev/null || true)
else
  TARGETS=("$@")
fi

UPDATE_COUNT=0

for file in "${TARGETS[@]}"; do
  [ -f "$file" ] || continue

  # Skip generated files
  [[ "$file" == */public/* ]] && continue

  # Check if file has CDN script or link tags
  grep -Eq 'src="https://cdnjs\.|href="https://cdnjs\.' "$file" 2>/dev/null || continue

  # Extract src="URL" patterns and update corresponding integrity attributes
  # Pattern: <script src="https://..." integrity="sha384-OLD_HASH"...>
  while IFS= read -r src_url; do
    # Skip if not a CDN URL
    [[ "$src_url" =~ ^https:// ]] || continue
    # Only allow specific CDN domains (policy: only cdnjs.cloudflare.com)
    [[ "$src_url" =~ ^https://(cdnjs\.cloudflare\.com)/ ]] || continue

    # Compute new hash
    new_hash=$(compute_sri "$src_url") || continue

    # Escape URL for use in sed
    escaped_url=$(escape_sed_pattern "$src_url")
    replacement_url=$(escape_sed_replacement "$src_url")
    replacement_hash=$(escape_sed_replacement "$new_hash")

    # Update or add integrity attribute
    if grep -Fq "src=\"$src_url\"" "$file"; then
      # 1) Replace existing integrity hashes for this URL
      sed_in_place "s|src=\"$escaped_url\"\\([^>]*\\)integrity=\"sha384-[^\"]*\"|src=\"$replacement_url\"\\1integrity=\"sha384-$replacement_hash\"|g" "$file"
      # 2) Add integrity attribute after src for this URL where missing
      sed_in_place "/src=\"$escaped_url\"/ {/integrity=/! s|src=\"$escaped_url\"|src=\"$replacement_url\" integrity=\"sha384-$replacement_hash\"|;}" "$file"
      # 3) Ensure crossorigin is present when integrity is set
      sed_in_place "/src=\"$escaped_url\".*integrity=/{/crossorigin=/! s|integrity=\"sha384-[^\"]*\"|& crossorigin=\"anonymous\"|;}" "$file"
      ((++UPDATE_COUNT))
    fi
  done < <(
    grep -E '<script[^>]*src="[^"]+"' "$file" 2>/dev/null |
      grep -oE 'src="[^"]+"' | sed -e 's/^src="//' -e 's/"$//' || true
  )

  # Extract href="URL" patterns and update corresponding integrity attributes
  # Pattern: <link href="https://..." integrity="sha384-OLD_HASH"...>
  while IFS= read -r href_url; do
    # Skip if not a CDN URL
    [[ "$href_url" =~ ^https:// ]] || continue
    # Only allow specific CDN domains (policy: only cdnjs.cloudflare.com)
    [[ "$href_url" =~ ^https://(cdnjs\.cloudflare\.com)/ ]] || continue

    # Compute new hash
    new_hash=$(compute_sri "$href_url") || continue

    # Escape URL for use in sed
    escaped_url=$(escape_sed_pattern "$href_url")
    replacement_url=$(escape_sed_replacement "$href_url")
    replacement_hash=$(escape_sed_replacement "$new_hash")

    # Update or add integrity attribute
    if grep -Fq "href=\"$href_url\"" "$file"; then
      # Check if integrity already exists for this URL
      if grep -Eq "href=\"$escaped_url\"[^>]*integrity" "$file"; then
        # Replace existing integrity hash
        sed_in_place "s|href=\"$escaped_url\"\\([^>]*\\)integrity=\"sha384-[^\"]*\"|href=\"$replacement_url\"\\1integrity=\"sha384-$replacement_hash\"|g" "$file"
      else
        # Add integrity attribute after href
        sed_in_place "/href=\"$escaped_url\"/{/integrity=/! s|href=\"$escaped_url\"|href=\"$replacement_url\" integrity=\"sha384-$replacement_hash\"|;}" "$file"
      fi
      # Ensure crossorigin is present when integrity is set
      sed_in_place "/href=\"$escaped_url\".*integrity=/{/crossorigin=/! s|integrity=\"sha384-[^\"]*\"|& crossorigin=\"anonymous\"|;}" "$file"
      ((++UPDATE_COUNT))
    fi
  done < <(
    grep -E '<link[^>]*href="[^"]+"' "$file" 2>/dev/null |
      grep -oE 'href="[^"]+"' | sed -e 's/^href="//' -e 's/"$//' || true
  )

done

# Clean up stale cache entries (older than 7 days)
find "$CACHE_DIR" -mtime +7 -delete 2>/dev/null || true

if [ $UPDATE_COUNT -gt 0 ]; then
  echo "Updated $UPDATE_COUNT SRI integrity hashes"
fi
