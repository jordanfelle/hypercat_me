#!/bin/bash
set -euo pipefail

# Store the repository root directory
REPO_ROOT="$(pwd)"

# Read Hugo version from .hugo-version file
if [ ! -f "${REPO_ROOT}/.hugo-version" ]; then
  echo "Error: .hugo-version file not found" >&2
  exit 1
fi
HUGO_VERSION="$(cat "${REPO_ROOT}/.hugo-version")"
# Validate version format to prevent injection in download URLs
if ! echo "${HUGO_VERSION}" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+$'; then
  echo "Error: Invalid Hugo version format in .hugo-version: ${HUGO_VERSION}" >&2
  exit 1
fi
HUGO_RELEASE="hugo_extended_${HUGO_VERSION}_linux-amd64"

# Create a temporary directory for Hugo
mkdir -p /tmp/hugo-bin
cd /tmp/hugo-bin

# Download Hugo if not already present
if [ ! -f "hugo" ]; then
  echo "Downloading Hugo ${HUGO_VERSION}..."
  if ! wget -q "https://github.com/gohugoio/hugo/releases/download/v${HUGO_VERSION}/${HUGO_RELEASE}.tar.gz" 2>/dev/null; then
    echo "Error: Failed to download Hugo ${HUGO_VERSION}. Check network connectivity and release availability." >&2
    exit 1
  fi

  if ! tar -xzf "${HUGO_RELEASE}.tar.gz"; then
    echo "Error: Failed to extract Hugo archive" >&2
    exit 1
  fi
  chmod +x hugo
fi

# Add Hugo to PATH
export PATH="/tmp/hugo-bin:$PATH"

# Verify Hugo version
echo "Using Hugo version:"
./hugo version

# Return to repo root and build
cd "$REPO_ROOT/content"
npm run build
