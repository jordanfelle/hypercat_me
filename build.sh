#!/bin/bash
set -euo pipefail

# Determine the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Read Hugo version from .hugo-version file
if [ ! -f "${SCRIPT_DIR}/.hugo-version" ]; then
  echo "Error: Hugo version file not found at ${SCRIPT_DIR}/.hugo-version" >&2
  exit 1
fi

# Sanitize Hugo version: remove carriage returns and whitespace
HUGO_VERSION=$(tr -d '\r' < "${SCRIPT_DIR}/.hugo-version" | tr -d '[:space:]')
if [ -z "${HUGO_VERSION}" ]; then
  echo "Error: Hugo version in ${SCRIPT_DIR}/.hugo-version is empty or invalid" >&2
  exit 1
fi

# Validate Hugo version format (e.g., 0.156.0)
if ! grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+$' <<< "${HUGO_VERSION}"; then
  echo "Error: Hugo version '${HUGO_VERSION}' in ${SCRIPT_DIR}/.hugo-version is invalid. Expected format: MAJOR.MINOR.PATCH (e.g., 0.156.0)" >&2
  exit 1
fi
HUGO_RELEASE="hugo_extended_${HUGO_VERSION}_linux-amd64"

# Use a user-owned directory under SCRIPT_DIR to safely cache the Hugo binary
HUGO_DIR="${SCRIPT_DIR}/.hugo-bin-${HUGO_VERSION}"
HUGO_BIN="${HUGO_DIR}/hugo"

# Create the versioned Hugo directory with restrictive permissions
mkdir -p "${HUGO_DIR}"
chmod 700 "${HUGO_DIR}"
cd "${HUGO_DIR}"

HUGO_BINARY_CHECKSUM_FILE="hugo.sha256"

# Verify an existing Hugo binary's checksum; sets NEED_DOWNLOAD=false if valid
NEED_DOWNLOAD=true
if [ -f "hugo" ] && [ -f "${HUGO_BINARY_CHECKSUM_FILE}" ]; then
  if command -v sha256sum >/dev/null 2>&1; then
    if sha256sum --check --status "${HUGO_BINARY_CHECKSUM_FILE}" 2>/dev/null; then
      NEED_DOWNLOAD=false
    fi
  elif command -v shasum >/dev/null 2>&1; then
    if shasum -a 256 --check "${HUGO_BINARY_CHECKSUM_FILE}" >/dev/null 2>&1; then
      NEED_DOWNLOAD=false
    fi
  fi
fi

# Download and verify Hugo if missing or checksum verification failed
if [ "${NEED_DOWNLOAD}" = "true" ]; then
  # Clean up any stale artifacts (including a potentially tampered binary)
  rm -f hugo "${HUGO_BINARY_CHECKSUM_FILE}" "${HUGO_RELEASE}.tar.gz" "hugo_${HUGO_VERSION}_checksums.txt"

  echo "Downloading Hugo ${HUGO_VERSION}..."
  wget -q -O "${HUGO_RELEASE}.tar.gz" "https://github.com/gohugoio/hugo/releases/download/v${HUGO_VERSION}/${HUGO_RELEASE}.tar.gz" || {
    echo "Failed to download Hugo ${HUGO_VERSION}" >&2
    rm -f "${HUGO_RELEASE}.tar.gz"
    exit 1
  }

  echo "Downloading Hugo checksums..."
  wget -q -O "hugo_${HUGO_VERSION}_checksums.txt" "https://github.com/gohugoio/hugo/releases/download/v${HUGO_VERSION}/hugo_${HUGO_VERSION}_checksums.txt" || {
    echo "Failed to download Hugo checksums" >&2
    rm -f "${HUGO_RELEASE}.tar.gz" "hugo_${HUGO_VERSION}_checksums.txt"
    exit 1
  }

  echo "Verifying Hugo archive checksum..."
  CHECKSUM_LINE="$(grep "  ${HUGO_RELEASE}.tar.gz$" "hugo_${HUGO_VERSION}_checksums.txt" || true)"
  if [ -z "${CHECKSUM_LINE}" ]; then
    echo "Checksum entry for ${HUGO_RELEASE}.tar.gz not found in hugo_${HUGO_VERSION}_checksums.txt" >&2
    rm -f "${HUGO_RELEASE}.tar.gz" "hugo_${HUGO_VERSION}_checksums.txt"
    exit 1
  fi
  # Prefer sha256sum, fall back to shasum -a 256 (for macOS and other environments)
  if command -v sha256sum >/dev/null 2>&1; then
    if ! sha256sum --check --status - <<< "${CHECKSUM_LINE}"; then
      echo "Checksum verification failed for Hugo ${HUGO_VERSION}" >&2
      rm -f "${HUGO_RELEASE}.tar.gz" "hugo_${HUGO_VERSION}_checksums.txt"
      exit 1
    fi
  elif command -v shasum >/dev/null 2>&1; then
    # shasum does not support --status, so silence output and rely on exit code
    if ! shasum -a 256 --check - >/dev/null 2>&1 <<< "${CHECKSUM_LINE}"; then
      echo "Checksum verification failed for Hugo ${HUGO_VERSION}" >&2
      rm -f "${HUGO_RELEASE}.tar.gz" "hugo_${HUGO_VERSION}_checksums.txt"
      exit 1
    fi
  else
    echo "Error: Neither sha256sum nor shasum is available; cannot verify Hugo archive checksum" >&2
    rm -f "${HUGO_RELEASE}.tar.gz" "hugo_${HUGO_VERSION}_checksums.txt"
    exit 1
  fi

  echo "Extracting Hugo archive..."
  tar -xzf "${HUGO_RELEASE}.tar.gz" || {
    echo "Failed to extract Hugo archive ${HUGO_RELEASE}.tar.gz" >&2
    rm -f "${HUGO_RELEASE}.tar.gz" "hugo_${HUGO_VERSION}_checksums.txt"
    exit 1
  }

  chmod +x hugo || {
    echo "Failed to make Hugo binary executable" >&2
    rm -f "${HUGO_RELEASE}.tar.gz" "hugo_${HUGO_VERSION}_checksums.txt" hugo
    exit 1
  }

  # Save binary checksum for integrity verification on future runs
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum hugo > "${HUGO_BINARY_CHECKSUM_FILE}"
  elif command -v shasum >/dev/null 2>&1; then
    shasum -a 256 hugo > "${HUGO_BINARY_CHECKSUM_FILE}"
  fi

  # Cleanup downloaded artifacts after successful extraction and setup
  rm -f "${HUGO_RELEASE}.tar.gz" "hugo_${HUGO_VERSION}_checksums.txt"
fi

# Verify Hugo binary exists and is executable
echo "Using Hugo binary:"
echo "${HUGO_BIN}"
if [ ! -x "${HUGO_BIN}" ]; then
  echo "Error: Hugo binary not found or not executable at ${HUGO_BIN}" >&2
  exit 1
fi

echo "Using Hugo version:"
HUGO_VERSION_OUTPUT="$("${HUGO_BIN}" version 2>&1)" || {
  echo "Error: Failed to execute Hugo version check" >&2
  echo "${HUGO_VERSION_OUTPUT}" >&2
  exit 1
}
echo "${HUGO_VERSION_OUTPUT}"

# Validate that the Hugo version matches the expected version and is extended
# Hugo version output format: "hugo v0.156.0-<hash>+extended ..." or "hugo v0.156.0+extended ..."
if [[ "${HUGO_VERSION_OUTPUT}" != *"v${HUGO_VERSION}-"* && "${HUGO_VERSION_OUTPUT}" != *"v${HUGO_VERSION}+"* ]]; then
  echo "Error: Hugo version mismatch. Expected v${HUGO_VERSION}, but got:" >&2
  echo "  ${HUGO_VERSION_OUTPUT}" >&2
  exit 1
fi

if [[ "${HUGO_VERSION_OUTPUT}" != *"extended"* ]]; then
  echo "Error: Non-extended Hugo binary detected. The extended version is required." >&2
  echo "  ${HUGO_VERSION_OUTPUT}" >&2
  exit 1
fi

# Change to content directory and run Hugo without --minify.
# Note: --minify is intentionally omitted as it causes JSON parse errors in cons pages.
if [ ! -d "${SCRIPT_DIR}/content" ]; then
  echo "Error: content directory not found at ${SCRIPT_DIR}/content" >&2
  exit 1
fi
cd "${SCRIPT_DIR}/content"
"${HUGO_BIN}"
