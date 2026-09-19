#!/usr/bin/env sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
VIDEO=${1:-}
PYTHON=${PYTHON:-python}

if ! command -v "$PYTHON" >/dev/null 2>&1; then
	printf 'Python executable was not found: %s. Install Python or set PYTHON to the correct executable.\n' "$PYTHON" >&2
	exit 1
fi

cd "$SCRIPT_DIR"

mkdir -p video frames exports gif models

printf '%s\n' '[1/3] Extracting video frames at 30 FPS...'
if ! sh "$SCRIPT_DIR/export_frames.sh" "$VIDEO"; then
	printf '%s\n' 'Pipeline stopped during frame extraction.' >&2
	exit 1
fi

printf '%s\n' '[2/3] Removing backgrounds...'
if ! "$PYTHON" "$SCRIPT_DIR/main.py"; then
	printf '%s\n' 'Pipeline stopped during background removal.' >&2
	exit 1
fi

printf '%s\n' '[3/3] Creating transparent GIF...'
if ! sh "$SCRIPT_DIR/frames_to_gif.sh"; then
	printf '%s\n' 'Pipeline stopped during GIF creation.' >&2
	exit 1
fi

printf '%s\n' 'Done: gif/result.gif'