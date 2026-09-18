#!/usr/bin/env sh
set -eu
mkdir -p models
curl -L https://huggingface.co/gobeldan/RMBG-2.0-GGUF/resolve/main/RMBG-2.0-F16.gguf -o models/RMBG-2.0-F16.gguf
printf '\nDownloaded models/RMBG-2.0-F16.gguf\n'
