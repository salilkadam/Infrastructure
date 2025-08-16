#!/usr/bin/env bash
set -euo pipefail
OUT=${1:-/etc/cdi/nvidia.yaml}
if ! command -v nvidia-ctk >/dev/null 2>&1; then echo "nvidia-ctk not installed" >&2; exit 1; fi
sudo mkdir -p "$(dirname "$OUT")"
sudo nvidia-ctk cdi generate --output="$OUT"
ls -l "$OUT" && echo "CDI kind lines:" && grep -n ^kind: "$OUT" || true
