#!/bin/bash
set -euo pipefail

# Determine the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Read Hugo version from .hugo-version file
HUGO_VERSION=$(cat "${SCRIPT_DIR}/.hugo-version")
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

# Verify Hugo version
echo "Using Hugo version:"
./hugo version

# Return to repository root and build
cd "${SCRIPT_DIR}/content"
npm run build
