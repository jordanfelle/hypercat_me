#!/bin/bash
set -euo pipefail

# Store the repository root directory
REPO_ROOT="$(pwd)"

# Download and use Hugo 0.156.0 explicitly
HUGO_VERSION="0.156.0"
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
