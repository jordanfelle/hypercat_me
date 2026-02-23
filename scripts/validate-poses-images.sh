#!/usr/bin/env bash
set -euo pipefail

# Validate and optionally resize poses images to 2000px max on long edge.
# This script is primarily used by the pre-commit hook to auto-resize images
# during local commits, preventing oversized images from being committed.
#
# This script can run in two modes:
# 1. Validation mode (default): Checks that images don't exceed 2000px on long edge
# 2. Auto-resize mode (with --crop flag): Automatically resizes images to 2000px max

MAX_DIMENSION=2000
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
POSES_DIR="${SCRIPT_DIR}/../content/content/poses"
AUTO_CROP=${1:-}
TMP_FILES=()

# Cleanup trap to remove temporary files on exit
cleanup() {
    for tmp_file in "${TMP_FILES[@]}"; do
        [ -f "$tmp_file" ] && rm -f "$tmp_file"
    done
}
trap cleanup EXIT INT TERM

# Check if ffprobe is available
if ! command -v ffprobe &> /dev/null; then
    echo "Error: FFmpeg (ffprobe) is required for image dimension validation."
    echo "Please install FFmpeg: brew install ffmpeg (macOS) or apt install ffmpeg (Ubuntu/Debian)"
    exit 1
fi

if ! command -v ffmpeg &> /dev/null && [ "$AUTO_CROP" = "--crop" ]; then
    echo "Error: FFmpeg is required for auto-cropping."
    echo "Please install FFmpeg: brew install ffmpeg (macOS) or apt install ffmpeg (Ubuntu/Debian)"
    exit 1
fi

if [[ ! -d "$POSES_DIR" ]]; then
    echo "Poses directory not found: $POSES_DIR"
    exit 1
fi

failures=()
cropped_files=()

# Find all images in poses subdirectories
image_files=()
while IFS= read -r img; do
    image_files+=("$img")
done < <(find "$POSES_DIR" -type f \( -iname "*.png" -o -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.gif" -o -iname "*.webp" -o -iname "*.avif" \))

if (( ${#image_files[@]} == 0 )); then
    echo "✅ No images found in poses directory"
    exit 0
fi

for image_path in "${image_files[@]}"; do
    pose_path=$(echo "$image_path" | sed "s|$POSES_DIR/||")

    # Get image dimensions using ffprobe
    if ! dimensions=$(ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=s=x:p=0 "$image_path" 2>/dev/null); then
        failures+=("$pose_path: unable to read image dimensions")
        continue
    fi

    width="${dimensions%x*}"
    height="${dimensions#*x}"

    # Skip if we couldn't parse dimensions
    if [[ -z "$width" ]] || [[ -z "$height" ]]; then
        failures+=("$pose_path: unable to parse image dimensions")
        continue
    fi

    # Calculate long edge
    if (( width > height )); then
        long_edge=$width
    else
        long_edge=$height
    fi

    if (( long_edge > MAX_DIMENSION )); then
        if [ "$AUTO_CROP" = "--crop" ]; then
            echo "⚙️  Resizing $pose_path: ${width}x${height} → max long edge $MAX_DIMENSION"

            # Use ffmpeg to resize the image while maintaining aspect ratio
            # scale filter constrains both dimensions to MAX_DIMENSION while maintaining aspect ratio
            image_dir="$(dirname "$image_path")"
            image_base="$(basename "$image_path")"
            tmp_image="$(mktemp "${image_dir}/.tmp-${image_base}.XXXXXX")"
            TMP_FILES+=("$tmp_image")

            if ffmpeg -i "$image_path" -vf "scale=${MAX_DIMENSION}:${MAX_DIMENSION}:force_original_aspect_ratio=decrease" -q:v 5 "$tmp_image" -y 2>/dev/null && mv -f "$tmp_image" "$image_path"; then
                cropped_files+=("$pose_path")
                # Remove from cleanup list since it was successfully moved
                TMP_FILES=("${TMP_FILES[@]/$tmp_image}")
            else
                failures+=("$pose_path: failed to resize image")
            fi
        else
            failures+=("$pose_path: ${width}x${height} exceeds maximum ${MAX_DIMENSION}px on long edge")
        fi
    fi
done

echo ""
if [ "$AUTO_CROP" = "--crop" ]; then
    if (( ${#cropped_files[@]} > 0 )); then
        echo "✅ Resized ${#cropped_files[@]} image(s):"
        printf '  - %s\n' "${cropped_files[@]}"
    fi
fi

if (( ${#failures[@]} == 0 )); then
    echo "✅ All poses images are within ${MAX_DIMENSION}px max dimension (${#image_files[@]} images checked)"
    exit 0
else
    echo "❌ Found ${#failures[@]} validation error(s):"
    printf '  - %s\n' "${failures[@]}"
    exit 1
fi
