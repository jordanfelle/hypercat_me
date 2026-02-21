#!/bin/bash

# This script converts images in the pose/* directories to webp and avif.

set -euo pipefail

base_dir="content/content/poses"
ordered_dirs=("solo" "duo" "triple" "groups")

converted_something=false
for dir in "${ordered_dirs[@]}"; do
    full_dir="$base_dir/$dir"
    if [ -d "$full_dir" ]; then
        find "$full_dir" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" \) | while read -r img; do
            webp_file="${img%.*}.webp"
            avif_file="${img%.*}.avif"

            if [ ! -f "$webp_file" ]; then
                if command -v cwebp &> /dev/null; then
                    echo "Converting $img to $webp_file"
                    cwebp -lossless "$img" -o "$webp_file"
                    converted_something=true
                else
                    echo "cwebp command not found, skipping webp conversion."
                fi
            fi

            if [ ! -f "$avif_file" ]; then
                if command -v avifenc &> /dev/null; then
                    echo "Converting $img to $avif_file"
                    avifenc "$img" "$avif_file"
                    converted_something=true
                else
                    echo "avifenc command not found, skipping avif conversion."
                fi
            fi
        done
    fi
done

if [ "$converted_something" = true ]; then
  echo "New image formats created. Please stage the changes and commit again."
  exit 1
fi

exit 0
