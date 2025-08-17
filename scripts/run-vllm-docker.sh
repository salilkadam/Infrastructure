#!/usr/bin/env bash
set -euo pipefail

MODEL=${MODEL:-EleutherAI/gpt-neox-20b}
PORT=${PORT:-8003}
CACHE_ROOT=${CACHE_ROOT:-/opt/ai-models/hf-cache}
CONTAINER_NAME=${CONTAINER_NAME:-vllm}
IMAGE=${IMAGE:-vllm/vllm-openai:latest}

echo "Checking NVIDIA driver and GPUs..."
nvidia-smi || { echo "nvidia-smi failed; install driver/toolkit first"; exit 1; }

echo "Ensuring HF cache dir at ${CACHE_ROOT}..."
sudo mkdir -p "${CACHE_ROOT}"
sudo chown -R "$USER":"$USER" "${CACHE_ROOT}" || true

echo "Pulling vLLM image ${IMAGE}..."
docker pull ${IMAGE}

echo "Stopping any existing container ${CONTAINER_NAME}..."
docker rm -f "${CONTAINER_NAME}" >/dev/null 2>&1 || true

echo "Starting vLLM (${MODEL}) on port ${PORT}..."
docker run -d --restart unless-stopped --name "${CONTAINER_NAME}" --gpus all \
  -p ${PORT}:8000 \
  -v "${CACHE_ROOT}":/root/.cache/huggingface \
  ${IMAGE} \
  --model "${MODEL}" \
  --download-dir /root/.cache/huggingface \
  --dtype auto \
  --tensor-parallel-size 1

sleep 3
echo "Checking vLLM logs..."
docker logs "${CONTAINER_NAME}" --tail=80 || true

echo "vLLM OpenAI server should be at http://localhost:${PORT}/v1/chat/completions"

