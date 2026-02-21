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
HUGO_RELEASE="hugo_extended_${HUGO_VERSION}_linux-amd64"

# Create a versioned temporary directory for Hugo to handle version changes
mkdir -p "/tmp/hugo-bin-${HUGO_VERSION}"
cd "/tmp/hugo-bin-${HUGO_VERSION}"

# Download Hugo if not already present
if [ ! -f "hugo" ]; then
  echo "Downloading Hugo ${HUGO_VERSION}..."
  wget -q "https://github.com/gohugoio/hugo/releases/download/v${HUGO_VERSION}/${HUGO_RELEASE}.tar.gz" || {
    echo "Failed to download Hugo ${HUGO_VERSION}" >&2
    exit 1
  }

  echo "Downloading Hugo checksums..."
  wget -q "https://github.com/gohugoio/hugo/releases/download/v${HUGO_VERSION}/hugo_${HUGO_VERSION}_checksums.txt" || {
    echo "Failed to download Hugo checksums" >&2
    exit 1
  }

  echo "Verifying Hugo archive checksum..."
  sha256sum --check --ignore-missing "hugo_${HUGO_VERSION}_checksums.txt" || {
    echo "Checksum verification failed for Hugo ${HUGO_VERSION}" >&2
    rm -f "${HUGO_RELEASE}.tar.gz" "hugo_${HUGO_VERSION}_checksums.txt"
    exit 1
  }

  echo "Extracting Hugo archive..."
  tar -xzf "${HUGO_RELEASE}.tar.gz" || {
    echo "Failed to extract Hugo archive ${HUGO_RELEASE}.tar.gz" >&2
    exit 1
  }

  chmod +x hugo || {
    echo "Failed to make Hugo binary executable" >&2
    exit 1
  }
fi

# Add Hugo to PATH
export PATH="/tmp/hugo-bin-${HUGO_VERSION}:$PATH"

# Verify Hugo binary and version using PATH
echo "Using Hugo binary:"
command -v hugo || { echo "Error: Hugo binary not found in PATH" >&2; exit 1; }

echo "Using Hugo version:"
hugo version

# Change to content directory and run the build
cd "${SCRIPT_DIR}/content"
npm run build
