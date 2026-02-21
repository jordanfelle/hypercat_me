#!/bin/bash

# This script renames all images in the pose/* directories to be numerically increasing.

set -euo pipefail

ordered_dirs=("solo" "duo" "triple" "groups")
base_dir="content/content/poses"

image_files=()
for dir in "${ordered_dirs[@]}"; do
  full_dir="$base_dir/$dir"
  if [ -d "$full_dir" ]; then
    while IFS= read -d '' -r file; do
      image_files+=("$file")
    done < <(find "$full_dir" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.gif" \) -print0 | sort -zV)
  fi
done

# Check if files are already numbered correctly
is_renaming_needed=false
if [ ${#image_files[@]} -eq 0 ]; then
  is_renaming_needed=false
else
  for i in "${!image_files[@]}"; do
    filename=$(basename -- "${image_files[$i]}")
    expected_filename="$((i+1)).${filename##*.}"
    if [ "$filename" != "$expected_filename" ]; then
      is_renaming_needed=true
      break
    fi
  done
fi

if [ "$is_renaming_needed" = false ]; then
  exit 0
fi

# Rename to temporary names
for i in "${!image_files[@]}"; do
  mv "${image_files[$i]}" "${image_files[$i]}.tmp"
done

# Rename to final numbered names
for i in "${!image_files[@]}"; do
  file="${image_files[$i]}.tmp"
  extension="${file%.tmp}"
  extension="${extension##*.}"
  dir=$(dirname "${image_files[$i]}")
  mv "$file" "$dir/$((i+1)).$extension"
done
