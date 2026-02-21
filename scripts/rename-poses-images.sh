#!/bin/bash

# This script renames all images in the pose/* directories to be numerically increasing.
# The renaming is done in the order of directories: solo, duo, triple, groups.
# Within each directory, files are sorted by modification date locally, or by filename in CI.
# The script is designed to be used as a pre-commit hook. It will exit with 1 if files are renamed.

set -euo pipefail

base_dir="content/content/poses"
ordered_dirs=("solo" "duo" "triple" "groups")

count=1
needs_rename=false
original_files=()
temp_files=()
final_files=()

# Detect CI environment - if in CI, use stable filename-based sorting
# to avoid spurious changes due to modification time differences.
# In local development, use modification time to order newly added files.
if [ -n "${CI:-}" ] || [ -n "${GITHUB_ACTIONS:-}" ]; then
    echo "CI environment detected - using stable filename sorting"
    SORT_METHOD="filename"
else
    SORT_METHOD="mtime"
fi

for dir in "${ordered_dirs[@]}"; do
    full_dir="$base_dir/$dir"
    if [ ! -d "$full_dir" ]; then
        continue
    fi

    # Choose sorting method based on environment
    if [ "$SORT_METHOD" = "filename" ]; then
        # In CI: sort by current filename to maintain stable order
        # Output only filename (no timestamp) so sort -V works correctly on filenames
        while read -r file; do
            if [ -z "$file" ]; then
                continue
            fi
            original_files+=("$file")
            extension="${file##*.}"
            new_name="$count.$extension"
            dir_path=$(dirname "$file")
            new_path="$dir_path/$new_name"

            if [ "$file" != "$new_path" ]; then
                needs_rename=true
            fi

            # Store temp and final names for later
            tmp_path="$dir_path/tmp_$$_${new_name}"
            temp_files+=("$tmp_path")
            final_files+=("$new_path")

            count=$((count+1))
        done < <(find "$full_dir" -type f \
                  \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.gif" -o -iname "*.webp" -o -iname "*.avif" \) \
                  -printf "%p\n" | sort -V)
    else
        # Locally: sort by modification time, then by filename for ties
        # Output timestamp and filename, then sort and remove timestamp
        while read -r file; do
            if [ -z "$file" ]; then
                continue
            fi
            original_files+=("$file")
            extension="${file##*.}"
            new_name="$count.$extension"
            dir_path=$(dirname "$file")
            new_path="$dir_path/$new_name"

            if [ "$file" != "$new_path" ]; then
                needs_rename=true
            fi

            # Store temp and final names for later
            tmp_path="$dir_path/tmp_$$_${new_name}"
            temp_files+=("$tmp_path")
            final_files+=("$new_path")

            count=$((count+1))
        done < <(find "$full_dir" -type f \
                  \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.gif" -o -iname "*.webp" -o -iname "*.avif" \) \
                  -printf "%T@ %p\n" | sort -n -k1,1 -k2,2V | cut -d' ' -f2-)
    fi
done


if [ "$needs_rename" = true ]; then
  echo "Renaming image files..."

  # 1. Rename to temporary names
  for ((i=0; i<${#original_files[@]}; i++)); do
    mv "${original_files[$i]}" "${temp_files[$i]}"
  done

  # 2. Rename from temporary to final names
  for ((i=0; i<${#temp_files[@]}; i++)); do
    mv "${temp_files[$i]}" "${final_files[$i]}"
  done

  echo "Image files have been renamed. Please stage the changes and commit again."
  exit 1
else
  echo "Image files are already correctly named."
fi

exit 0
