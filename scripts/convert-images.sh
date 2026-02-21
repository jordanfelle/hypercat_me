#!/bin/bash

# This script converts images in the pose/* directories to webp and avif, and deletes the original files.

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

            converted_to_webp=false
            if [ ! -f "$webp_file" ]; then
                if command -v cwebp &> /dev/null; then
                    echo "Converting $img to $webp_file"
                    if cwebp -lossless "$img" -o "$webp_file"; then
                        converted_to_webp=true
                        converted_something=true
                    else
                        echo "Failed to convert $img to $webp_file"
                        rm -f "$webp_file"
                    fi
                else
                    echo "cwebp command not found, skipping webp conversion."
                fi
            fi

            converted_to_avif=false
            if [ ! -f "$avif_file" ]; then
                if command -v avifenc &> /dev/null; then
                    echo "Converting $img to $avif_file"
                    if avifenc "$img" "$avif_file"; then
                        converted_to_avif=true
                        converted_something=true
                    else
                        echo "Failed to convert $img to $avif_file"
                        rm -f "$avif_file"
                    fi
                else
                    echo "avifenc command not found, skipping avif conversion."
                fi
            fi

            if [ "$converted_to_webp" = true ] || [ "$converted_to_avif" = true ]; then
                echo "Deleting original image $img"
                rm "$img"
            fi
        done
    fi
done

if [ "$converted_something" = true ]; then
  echo "New image formats created and originals deleted. Please stage the changes and commit again."
  exit 1
fi

exit 0
