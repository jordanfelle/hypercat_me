#!/bin/bash
# Update Hugo archive checksum when .hugo-version changes
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

HUGO_VERSION_FILE="${REPO_ROOT}/.hugo-version"
CHECKSUM_FILE="${REPO_ROOT}/.hugo-archive-checksum"

# Exit early if hugo version file doesn't exist
if [ ! -f "${HUGO_VERSION_FILE}" ]; then
  echo "No .hugo-version file found, skipping Hugo checksum update"
  exit 0
fi

# Read and sanitize Hugo version
HUGO_VERSION=$(tr -d '\r' < "${HUGO_VERSION_FILE}" | tr -d '[:space:]')
if [ -z "${HUGO_VERSION}" ]; then
  echo "Error: Hugo version in ${HUGO_VERSION_FILE} is empty or invalid" >&2
  exit 1
fi

# Validate Hugo version format (e.g., 0.157.0)
if ! grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+$' <<< "${HUGO_VERSION}"; then
  echo "Error: Hugo version '${HUGO_VERSION}' is invalid. Expected format: MAJOR.MINOR.PATCH" >&2
  exit 1
fi

HUGO_RELEASE="hugo_extended_${HUGO_VERSION}_linux-amd64"
HUGO_ARCHIVE="${HUGO_RELEASE}.tar.gz"

# Check if checksum file exists and is up-to-date
if [ -f "${CHECKSUM_FILE}" ]; then
  if grep -q "${HUGO_ARCHIVE}" "${CHECKSUM_FILE}"; then
    echo "✓ Hugo archive checksum already up-to-date for version ${HUGO_VERSION}"
    exit 0
  fi
fi

echo "Updating Hugo archive checksum for version ${HUGO_VERSION}..."

# Create a temporary directory for downloading
TEMP_DIR=$(mktemp -d)
trap 'rm -rf "${TEMP_DIR}"' EXIT

cd "${TEMP_DIR}"

# Download the Hugo archive
DOWNLOAD_URL="https://github.com/gohugoio/hugo/releases/download/v${HUGO_VERSION}/${HUGO_ARCHIVE}"
echo "Downloading Hugo archive from ${DOWNLOAD_URL}..."

if command -v wget >/dev/null 2>&1; then
  wget -q -O "${HUGO_ARCHIVE}" "${DOWNLOAD_URL}" || {
    echo "Error: Failed to download Hugo ${HUGO_VERSION}" >&2
    exit 1
  }
elif command -v curl >/dev/null 2>&1; then
  curl -fsSL -o "${HUGO_ARCHIVE}" "${DOWNLOAD_URL}" || {
    echo "Error: Failed to download Hugo ${HUGO_VERSION}" >&2
    exit 1
  }
else
  echo "Error: Neither wget nor curl is available; cannot download Hugo ${HUGO_VERSION}" >&2
  exit 1
fi

# Compute the SHA256 checksum
echo "Computing SHA256 checksum..."
if command -v sha256sum >/dev/null 2>&1; then
  CHECKSUM=$(sha256sum "${HUGO_ARCHIVE}" | awk '{print $1}')
elif command -v shasum >/dev/null 2>&1; then
  CHECKSUM=$(shasum -a 256 "${HUGO_ARCHIVE}" | awk '{print $1}')
else
  echo "Error: Neither sha256sum nor shasum is available; cannot compute checksum" >&2
  exit 1
fi

# Update the checksum file
echo "${CHECKSUM}  ${HUGO_ARCHIVE}" > "${CHECKSUM_FILE}"
echo "✓ Updated ${CHECKSUM_FILE} with checksum: ${CHECKSUM}"

# The file will be automatically staged by pre-commit
exit 0
