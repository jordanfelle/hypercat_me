#!/bin/bash
set -euo pipefail

# Ensure Hugo 0.156.0 is used during build
export HUGO_VERSION="0.156.0"

# Run the npm build script from content directory
cd content
npm run build
