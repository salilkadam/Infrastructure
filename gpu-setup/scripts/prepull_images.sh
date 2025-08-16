#!/usr/bin/env bash
set -euo pipefail
IMAGES=(
  docker.io/nvidia/cuda:12.4.1-base-ubuntu22.04
  docker.io/nvidia/cuda:12.4.1-runtime-ubuntu22.04
)
for IMG in "${IMAGES[@]}"; do echo "Pulling $IMG via ctr..."; sudo ctr -n k8s.io images pull "$IMG" | cat; echo; done
