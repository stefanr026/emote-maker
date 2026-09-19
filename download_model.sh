#!/usr/bin/env sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
VISION_DIR="$SCRIPT_DIR/vision.cpp"
MODEL_DIR="$SCRIPT_DIR/models"
MODEL_PATH="$MODEL_DIR/RMBG-2.0-F16.gguf"

mkdir -p "$MODEL_DIR"

if [ ! -d "$VISION_DIR" ]; then
  printf '%s\n' 'vision.cpp is missing. Cloning and building...'
  git clone --recursive https://github.com/Acly/vision.cpp.git "$VISION_DIR"
fi

if [ ! -x "$VISION_DIR/build/bin/vision-cli" ]; then
  printf '%s\n' 'vision.cpp is present but not built. Configuring and building...'
  cmake -S "$VISION_DIR" -B "$VISION_DIR/build"
  cmake --build "$VISION_DIR/build" --config Release
fi

if [ ! -f "$MODEL_PATH" ]; then
  curl -L https://huggingface.co/gobeldan/RMBG-2.0-GGUF/resolve/main/RMBG-2.0-F16.gguf -o "$MODEL_PATH"
fi

printf '\nReady: %s\n' "$MODEL_PATH"
