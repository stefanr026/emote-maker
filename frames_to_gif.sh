#!/usr/bin/env sh
set -eu

INPUT_DIR=${1:-exports}
OUTPUT_FILE=${2:-gif/result.gif}
FPS=${FPS:-30}

if ! command -v ffmpeg >/dev/null 2>&1; then
  printf '%s\n' 'ffmpeg was not found in PATH. Install ffmpeg and try again.' >&2
  exit 1
fi

if [ ! -d "$INPUT_DIR" ]; then
  printf 'The input folder does not exist: %s. Run background removal first so the folder is created.\n' "$INPUT_DIR" >&2
  exit 1
fi

if ! find "$INPUT_DIR" -maxdepth 1 -type f -iname '*.png' -print -quit | grep -q .; then
  printf 'No PNG frames found in %s. Run the full pipeline again or check that background removal completed successfully.\n' "$INPUT_DIR" >&2
  exit 1
fi

mkdir -p "$(dirname "$OUTPUT_FILE")"
printf 'Creating transparent GIF from %s at %s fps...\n' "$INPUT_DIR" "$FPS"

# reserve_transparent keeps one palette entry transparent; alpha_threshold
# prevents the background from being replaced with an opaque palette color.
if ! ffmpeg -hide_banner -loglevel warning -y \
  -framerate "$FPS" \
  -pattern_type glob -i "$INPUT_DIR/*.png" \
  -filter_complex "[0:v]split[preview][palette_source];[palette_source]palettegen=reserve_transparent=1:stats_mode=diff[palette];[preview][palette]paletteuse=alpha_threshold=128" \
  -loop 0 \
  "$OUTPUT_FILE"; then
  printf 'ffmpeg could not create the GIF at %s. Check the PNG files and available disk space, then try again.\n' "$OUTPUT_FILE" >&2
  exit 1
fi

printf 'Created: %s\n' "$OUTPUT_FILE"
