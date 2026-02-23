#!/usr/bin/env bash
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

UPDATE_ONLY=false
ARGS=()
for arg in "$@"; do
  case "$arg" in
    --update-only)
      UPDATE_ONLY=true
      ;;
    *)
      ARGS+=("$arg")
      ;;
  esac
done

# Cache directory for downloads to avoid redundant requests
if [ -n "${XDG_CACHE_HOME-}" ]; then
  CACHE_DIR="${XDG_CACHE_HOME%/}/sri-hashes"
else
  CACHE_DIR="$REPO_ROOT/.cache/sri-hashes"
fi
mkdir -p "$CACHE_DIR" || {
  echo "Error: failed to create cache directory '$CACHE_DIR'" >&2
  exit 1
}

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

  # Download script and compute SHA384 hash in base64
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
  if ! hash=$(curl -fsSL --connect-timeout 5 --max-time 30 --retry 3 "$url" | openssl dgst -sha384 -binary | base64_no_wrap); then
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
if [ ${#ARGS[@]} -eq 0 ]; then
  # If no args, process all HTML files (skip generated/public)
  while IFS= read -r -d '' file; do
    TARGETS+=("$file")
  done < <(find "$REPO_ROOT" -name "*.html" -type f \
    ! -path "*/public/*" ! -path "*/resources/*" -print0 2>/dev/null || true)
else
  TARGETS=("${ARGS[@]}")
fi

UPDATE_COUNT=0
MISSING_COUNT=0
ERROR_URLS=()

for file in "${TARGETS[@]}"; do
  [ -f "$file" ] || continue

  # Skip generated files
  [[ "$file" == */public/* ]] && continue

  # Check if file has CDN script or link tags
  grep -Eq '<script[^>]*src="https://(cdnjs|code\.jquery|cdn)\.|<link[^>]*href="https://(cdnjs|code\.jquery|cdn)\.' "$file" 2>/dev/null || continue

  echo "Processing: $file" >&2

  # Extract src="URL" patterns for scripts
  while IFS= read -r src_url; do
    [ -z "$src_url" ] && continue
    # Skip if not from an allowed CDN
    [[ "$src_url" =~ ^https://(cdnjs\.cloudflare\.com|code\.jquery\.com|cdn\.jsdelivr\.net)/ ]] || continue

    echo "  Checking script: $src_url" >&2

    # Compute new hash
    if ! new_hash=$(compute_sri "$src_url" 2>/dev/null); then
      echo "  ⚠ Failed to compute hash for: $src_url" >&2
      ERROR_URLS+=("$src_url")
      ((++MISSING_COUNT))
      continue
    fi

    # Escape regex metacharacters for safe sed patterns
    escaped_url=$(escape_sed_pattern "$src_url")
    replacement_url=$(escape_sed_replacement "$src_url")
    replacement_hash=$(escape_sed_replacement "$new_hash")

    # Check if the file has this src attribute at all
    if grep -Fq "src=\"$src_url\"" "$file"; then
      has_integrity=false
      has_missing_integrity=false
      if grep -F "src=\"$src_url\"" "$file" | grep -Fq 'integrity='; then
        has_integrity=true
      fi
      if grep -F "src=\"$src_url\"" "$file" | grep -Fv 'integrity=' >/dev/null 2>&1; then
        has_missing_integrity=true
      fi

      # 1. Update existing integrity hashes for this URL (on any matching tag lines)
      if [[ "$has_integrity" == true ]]; then
        sed_in_place "s|src=\"$escaped_url\"\([^>]*\)integrity=\"sha384-[^\"]*\"|src=\"$replacement_url\"\1integrity=\"sha384-$replacement_hash\"|g" "$file"
        echo "  ✓ Updated hash for script (existing integrity): $src_url" >&2
      fi

      # 2. Add integrity attribute to any matching tag lines that lack integrity
      #    This only affects lines that contain this src URL and do NOT already contain integrity=
      if [[ "$has_missing_integrity" == true ]]; then
        sed_in_place "/src=\"$escaped_url\"/{/integrity=/! s|src=\"$escaped_url\"|src=\"$replacement_url\" integrity=\"sha384-$replacement_hash\"|;}" "$file"
        echo "  ✓ Added integrity to script (previously missing): $src_url" >&2
      fi

      # 3. Ensure crossorigin is present on tags with this URL and an integrity attribute
      if [[ "$has_integrity" == true || "$has_missing_integrity" == true ]]; then
        sed_in_place "/src=\"$escaped_url\".*integrity=/{/crossorigin=/! s|integrity=\"sha384-[^\"]*\"|& crossorigin=\"anonymous\"|;}" "$file"
        ((++UPDATE_COUNT))
      fi
    fi
  done < <(
    grep -E '<script[^>]*src="[^"]+"' "$file" 2>/dev/null |
      grep -oE 'src="[^"]+"' | sed -e 's/^src="//' -e 's/"$//' || true
  ) || true

  # Extract href="URL" patterns for links
  while IFS= read -r href_url; do
    [ -z "$href_url" ] && continue
    # Skip if not from an allowed CDN
    [[ "$href_url" =~ ^https://(cdnjs\.cloudflare\.com|code\.jquery\.com|cdn\.jsdelivr\.net)/ ]] || continue

    echo "  Checking link: $href_url" >&2

    # Compute new hash
    if ! new_hash=$(compute_sri "$href_url" 2>/dev/null); then
      echo "  ⚠ Failed to compute hash for: $href_url" >&2
      ERROR_URLS+=("$href_url")
      ((++MISSING_COUNT))
      continue
    fi

    # Escape regex metacharacters for safe sed patterns
    escaped_url=$(escape_sed_pattern "$href_url")
    replacement_url=$(escape_sed_replacement "$href_url")
    replacement_hash=$(escape_sed_replacement "$new_hash")

    # Check if the file has this href attribute at all
    if grep -Fq "href=\"$href_url\"" "$file"; then
      has_integrity=false
      has_missing_integrity=false
      if grep -F "href=\"$href_url\"" "$file" | grep -Fq 'integrity='; then
        has_integrity=true
      fi
      if grep -F "href=\"$href_url\"" "$file" | grep -Fv 'integrity=' >/dev/null 2>&1; then
        has_missing_integrity=true
      fi

      # 1. Update existing integrity hashes for this URL (on any matching tag lines)
      if [[ "$has_integrity" == true ]]; then
        sed_in_place "s|href=\"$escaped_url\"\([^>]*\)integrity=\"sha384-[^\"]*\"|href=\"$replacement_url\"\1integrity=\"sha384-$replacement_hash\"|g" "$file"
        echo "  ✓ Updated hash for link (existing integrity): $href_url" >&2
      fi

      # 2. Add integrity attribute to any matching tag lines that lack integrity
      #    This only affects lines that contain this href URL and do NOT already contain integrity=
      if [[ "$has_missing_integrity" == true ]]; then
        sed_in_place "/href=\"$escaped_url\"/{/integrity=/! s|href=\"$escaped_url\"|href=\"$replacement_url\" integrity=\"sha384-$replacement_hash\"|;}" "$file"
        echo "  ✓ Added integrity to link (previously missing): $href_url" >&2
      fi

      # 3. Ensure crossorigin is present on tags with this URL and an integrity attribute
      if [[ "$has_integrity" == true || "$has_missing_integrity" == true ]]; then
        sed_in_place "/href=\"$escaped_url\".*integrity=/{/crossorigin=/! s|integrity=\"sha384-[^\"]*\"|& crossorigin=\"anonymous\"|;}" "$file"
        ((++UPDATE_COUNT))
      fi
    fi
  done < <(
    grep -E '<link[^>]*href="[^"]+"' "$file" 2>/dev/null |
      grep -oE 'href="[^"]+"' | sed -e 's/^href="//' -e 's/"$//' || true
  ) || true
done

if [ "$UPDATE_ONLY" = "true" ]; then
  find "$CACHE_DIR" -mtime +7 -delete 2>/dev/null || true
  echo "" >&2
  if [ $UPDATE_COUNT -gt 0 ]; then
    echo "✓ Updated/added $UPDATE_COUNT SRI integrity hashes" >&2
  fi
  if [ $MISSING_COUNT -gt 0 ]; then
    echo "⚠ Failed to generate hashes for $MISSING_COUNT URLs:" >&2
    printf '%s\n' "${ERROR_URLS[@]}" | sort -u >&2
    exit 1
  fi
  exit 0
fi

# Validate that all CDN resources have integrity attributes
echo "Validating SRI attributes..." >&2
VALIDATION_FAILED=0
for file in "${TARGETS[@]}"; do
  [ -f "$file" ] || continue
  [[ "$file" == */public/* ]] && continue

  # Find all CDN script src= attributes without integrity
  missing_src=$(grep -E '<script[^>]*src="https?://[^"]+"' "$file" 2>/dev/null | while IFS= read -r line; do
    if ! echo "$line" | grep -Fq 'integrity='; then
      echo "$line" | sed -n 's/.*src="\([^"]*\)".*/\1/p'
    fi
  done | grep -E '(cdnjs\.cloudflare\.com|code\.jquery\.com|cdn\.jsdelivr\.net)' || true)
  if [ -n "$missing_src" ]; then
    echo "❌ Missing SRI on script in $file:" >&2
    echo "$missing_src" | while read -r url; do
      echo "  - $url" >&2
    done
    VALIDATION_FAILED=1
  fi

  missing_src_crossorigin=$(grep -E '<script[^>]*src="https?://[^"]+"' "$file" 2>/dev/null | while IFS= read -r line; do
    if echo "$line" | grep -Fq 'integrity=' && ! echo "$line" | grep -Fq 'crossorigin='; then
      echo "$line" | sed -n 's/.*src="\([^"]*\)".*/\1/p'
    fi
  done | grep -E '(cdnjs\.cloudflare\.com|code\.jquery\.com|cdn\.jsdelivr\.net)' || true)
  if [ -n "$missing_src_crossorigin" ]; then
    echo "❌ Missing crossorigin on script in $file:" >&2
    echo "$missing_src_crossorigin" | while read -r url; do
      echo "  - $url" >&2
    done
    VALIDATION_FAILED=1
  fi

  # Find all CDN link href= attributes without integrity
  missing_href=$(grep -E '<link[^>]*href="https?://[^"]+"' "$file" 2>/dev/null | while IFS= read -r line; do
    if ! echo "$line" | grep -Fq 'integrity='; then
      echo "$line" | sed -n 's/.*href="\([^"]*\)".*/\1/p'
    fi
  done | grep -E '(cdnjs\.cloudflare\.com|code\.jquery\.com|cdn\.jsdelivr\.net)' || true)
  if [ -n "$missing_href" ]; then
    echo "❌ Missing SRI on link in $file:" >&2
    echo "$missing_href" | while read -r url; do
      echo "  - $url" >&2
    done
    VALIDATION_FAILED=1
  fi

  missing_href_crossorigin=$(grep -E '<link[^>]*href="https?://[^"]+"' "$file" 2>/dev/null | while IFS= read -r line; do
    if echo "$line" | grep -Fq 'integrity=' && ! echo "$line" | grep -Fq 'crossorigin='; then
      echo "$line" | sed -n 's/.*href="\([^"]*\)".*/\1/p'
    fi
  done | grep -E '(cdnjs\.cloudflare\.com|code\.jquery\.com|cdn\.jsdelivr\.net)' || true)
  if [ -n "$missing_href_crossorigin" ]; then
    echo "❌ Missing crossorigin on link in $file:" >&2
    echo "$missing_href_crossorigin" | while read -r url; do
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
