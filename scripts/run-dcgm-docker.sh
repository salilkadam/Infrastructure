#!/usr/bin/env bash
set -euo pipefail

CONTAINER_NAME="dcgm-exp"
IMAGE="nvidia/dcgm-exporter:3.4.0-3.3.0-ubuntu22.04"
PORT=9400

echo "Starting DCGM exporter ${IMAGE} on port ${PORT}..."
docker rm -f "${CONTAINER_NAME}" >/dev/null 2>&1 || true
docker run -d --restart unless-stopped --name "${CONTAINER_NAME}" \
  --gpus all --privileged -p ${PORT}:9400 ${IMAGE}

sleep 2
echo "Checking metrics endpoint..."
curl -fsS http://localhost:${PORT}/metrics | head -n 5 || true

