#!/usr/bin/env bash
set -euo pipefail

MODEL=${MODEL:-openai/gpt-oss-20b}
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

echo "Starting vLLM (${MODEL}) on port ${PORT} with gpt-oss wheels..."
docker run -d --restart unless-stopped --name "${CONTAINER_NAME}" --gpus all \
  -p ${PORT}:8000 \
  -v "${CACHE_ROOT}":/root/.cache/huggingface \
  ${IMAGE} \
  bash -lc "pip install --upgrade pip && \
    pip install --pre 'vllm==0.10.1+gptoss' \
      --extra-index-url https://wheels.vllm.ai/gpt-oss/ \
      --extra-index-url https://download.pytorch.org/whl/nightly/cu128 \
      --index-strategy unsafe-best-match && \
    vllm serve '${MODEL}' --download-dir /root/.cache/huggingface --dtype auto --tensor-parallel-size 1"

sleep 3
echo "Checking vLLM logs..."
docker logs "${CONTAINER_NAME}" --tail=80 || true

echo "vLLM OpenAI server should be at http://localhost:${PORT}/v1/chat/completions"

