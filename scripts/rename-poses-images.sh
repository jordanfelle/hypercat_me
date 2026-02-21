#!/bin/bash

# This script renames all images in the pose/* directories to be numerically increasing based on modification date.
# The ordering of directories is solo, duo, triple, groups.
# The script is designed to be used as a pre-commit hook. It will exit with 1 if files are renamed.

set -euo pipefail

base_dir="content/content/poses"
ordered_dirs=("solo" "duo" "triple" "groups")

# Create a temporary file to store the list of files, sorted by modification date
sorted_file_list=$(mktemp)
trap 'rm -f -- "$sorted_file_list"' EXIT

# Create a list of directories to search
search_dirs=()
for dir in "${ordered_dirs[@]}"; do
    if [ -d "$base_dir/$dir" ]; then
        search_dirs+=("$base_dir/$dir")
    fi
done

# If no directories are found, exit gracefully
if [ ${#search_dirs[@]} -eq 0 ]; then
    echo "No pose directories found to process."
    exit 0
fi

# Find all image files and sort them by modification date (oldest first)
find "${search_dirs[@]}" -type f \
  \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.gif" -o -iname "*.webp" -o -iname "*.avif" \) \
  -printf "%T@ %p\n" | sort -n | cut -d' ' -f2- > "$sorted_file_list"

# If no files are found, exit gracefully
if [ ! -s "$sorted_file_list" ]; then
    echo "No image files found to process."
    exit 0
fi

# Check if any files need renaming by comparing current names with expected names
count=1
needs_rename=false
temp_files=()
final_files=()
original_files=()

while read -r file; do
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
done < "$sorted_file_list"


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
