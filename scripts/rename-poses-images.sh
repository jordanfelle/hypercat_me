#!/bin/bash

# This script renames all images in the pose/* directories to be numerically increasing.
# The renaming is done in the order of directories: solo, duo, triple, groups.
# Within each directory, files are sorted by modification date.
# The script is designed to be used as a pre-commit hook. It will exit with 1 if files are renamed.

set -euo pipefail

base_dir="content/content/poses"
ordered_dirs=("solo" "duo" "triple" "groups")

count=1
needs_rename=false
original_files=()
temp_files=()
final_files=()

for dir in "${ordered_dirs[@]}"; do
    full_dir="$base_dir/$dir"
    if [ ! -d "$full_dir" ]; then
        continue
    fi

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
              -printf "%T@ %p\n" | sort -n | cut -d' ' -f2-)
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
