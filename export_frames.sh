#!/usr/bin/env sh
set -eu

VIDEO_DIR=${VIDEO_DIR:-video}
VIDEO=${1:-}
OUTPUT_DIR=${2:-}

if ! command -v ffmpeg >/dev/null 2>&1; then
  printf '%s\n' 'ffmpeg was not found in PATH. Install ffmpeg and try again.' >&2
  exit 1
fi

mkdir -p "$VIDEO_DIR"

if [ -n "$VIDEO" ]; then
  if [ ! -f "$VIDEO" ] && [ -f "$VIDEO_DIR/$VIDEO" ]; then
    VIDEO="$VIDEO_DIR/$VIDEO"
  elif [ ! -f "$VIDEO" ]; then
    printf 'The video file was not found: %s. Use a filename from %s or provide a valid video path.\n' "$VIDEO" "$VIDEO_DIR" >&2
    exit 1
  fi
fi

if [ -z "$VIDEO" ]; then
  VIDEO=$(find "$VIDEO_DIR" -maxdepth 1 -type f \( \
    -iname '*.mp4' -o -iname '*.mov' -o -iname '*.mkv' -o \
    -iname '*.avi' -o -iname '*.webm' -o -iname '*.m4v' \
  \) -print -quit)
fi

if [ -z "$VIDEO" ] || [ ! -f "$VIDEO" ]; then
  printf 'No supported video found in %s. Put a .mp4, .mov, .mkv, .avi, .webm, or .m4v file in that folder.\n' "$VIDEO_DIR" >&2
  printf 'Usage: %s [video-name-or-path] [output-folder]\n' "$0" >&2
  exit 1
fi

if [ -z "$OUTPUT_DIR" ]; then
  OUTPUT_DIR="frames"
  CLEAN_DIR="frames"
else
  CLEAN_DIR="$OUTPUT_DIR"
fi

mkdir -p "$CLEAN_DIR"
find "$CLEAN_DIR" -mindepth 1 -maxdepth 1 -exec rm -rf {} +
mkdir -p "$OUTPUT_DIR"
printf 'Exporting frames from %s to %s...\n' "$VIDEO" "$OUTPUT_DIR"

if ! ffmpeg -hide_banner -loglevel warning -y \
  -i "$VIDEO" \
  -vf 'fps=30' \
  "$OUTPUT_DIR/frame-%06d.png"; then
  printf 'ffmpeg could not read or convert %s. Check that the video is playable and supported by ffmpeg.\n' "$VIDEO" >&2
  exit 1
fi

printf 'Frames written to: %s\n' "$OUTPUT_DIR"