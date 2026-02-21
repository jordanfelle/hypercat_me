#!/bin/bash
set -euo pipefail

# Download and use Hugo 0.156.0 explicitly
HUGO_VERSION="0.156.0"
HUGO_RELEASE="hugo_extended_${HUGO_VERSION}_linux-amd64"

# Create a temporary directory for Hugo
mkdir -p /tmp/hugo-bin
cd /tmp/hugo-bin

# Download Hugo if not already present
if [ ! -f "hugo" ]; then
  echo "Downloading Hugo ${HUGO_VERSION}..."
  wget -q "https://github.com/gohugoio/hugo/releases/download/v${HUGO_VERSION}/${HUGO_RELEASE}.tar.gz"
  tar -xzf "${HUGO_RELEASE}.tar.gz"
  chmod +x hugo
fi

# Add Hugo to PATH
export PATH="/tmp/hugo-bin:$PATH"

# Verify Hugo version
echo "Using Hugo version:"
./hugo version

# Return to repo root and build
cd -
cd content
npm run build
