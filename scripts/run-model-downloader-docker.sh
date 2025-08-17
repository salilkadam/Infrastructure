#!/usr/bin/env bash
set -euo pipefail

# Downloads models using a throwaway Python Docker container.
# Models and HF cache are stored under /opt/ai-models so Triton can access them.

MODEL_ROOT=${MODEL_ROOT:-/opt/ai-models}
IMAGE=${IMAGE:-python:3.12-slim}
REPO_DIR=${REPO_DIR:-/home/salil/Infrastructure}

echo "Ensuring model root exists at ${MODEL_ROOT}..."
sudo mkdir -p "${MODEL_ROOT}/hf-cache"
sudo chown -R "$USER":"$USER" "${MODEL_ROOT}"

echo "Pulling ${IMAGE}..."
docker pull ${IMAGE}

echo "Running model downloads in Docker..."
docker run --rm \
  -e MODEL_ROOT=/models \
  -e HF_HOME=/models/hf-cache \
  -e HUGGINGFACE_HUB_DISABLE_TELEMETRY=1 \
  -e HUGGINGFACE_HUB_TOKEN="${HUGGINGFACE_HUB_TOKEN:-}" \
  -v "${MODEL_ROOT}":/models \
  -v "${REPO_DIR}":/workspace \
  ${IMAGE} bash -lc "pip install --no-cache-dir --upgrade pip && pip install --no-cache-dir 'huggingface_hub>=0.24.0' && python /workspace/scripts/download-models.py"

echo "Downloads complete."

