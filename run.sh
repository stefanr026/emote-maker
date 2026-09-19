#!/usr/bin/env sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
VIDEO=${1:-}
PYTHON=${PYTHON:-python}

cd "$SCRIPT_DIR"

if [ ! -f "$SCRIPT_DIR/models/RMBG-2.0-F16.gguf" ] || [ ! -x "$SCRIPT_DIR/vision.cpp/build/bin/vision-cli" ]; then
	printf '%s\n' '[1/4] Preparing vision.cpp and the model...'
	if ! sh "$SCRIPT_DIR/download_model.sh"; then
		printf '%s\n' 'Pipeline stopped during setup.' >&2
		exit 1
	fi
else
	printf '%s\n' '[1/4] vision.cpp and the model are ready.'
fi

if ! command -v "$PYTHON" >/dev/null 2>&1; then
	printf 'Python executable was not found: %s. Install Python or set PYTHON to the correct executable.\n' "$PYTHON" >&2
	exit 1
fi

mkdir -p video frames exports gif models

printf '%s\n' '[2/4] Extracting video frames at 30 FPS...'
if ! sh "$SCRIPT_DIR/export_frames.sh" "$VIDEO"; then
	printf '%s\n' 'Pipeline stopped during frame extraction.' >&2
	exit 1
fi

printf '%s\n' '[3/4] Removing backgrounds...'
if ! "$PYTHON" "$SCRIPT_DIR/main.py"; then
	printf '%s\n' 'Pipeline stopped during background removal.' >&2
	exit 1
fi

printf '%s\n' '[4/4] Creating transparent GIF...'
if ! sh "$SCRIPT_DIR/frames_to_gif.sh"; then
	printf '%s\n' 'Pipeline stopped during GIF creation.' >&2
	exit 1
fi

printf '%s\n' 'Done: gif/result.gif'