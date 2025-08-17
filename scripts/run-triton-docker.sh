#!/usr/bin/env bash
set -euo pipefail

# Config
TRITON_TAG="24.08-py3"
MODEL_ROOT="/mnt/ssd/models"
CONTAINER_NAME="triton1"
HOST_IP="192.168.0.110"

echo "Checking NVIDIA driver and GPUs..."
nvidia-smi || { echo "nvidia-smi failed; install driver/toolkit first"; exit 1; }

echo "Pulling Triton image nvcr.io/nvidia/tritonserver:${TRITON_TAG} (login required if private)..."
docker pull nvcr.io/nvidia/tritonserver:${TRITON_TAG}

echo "Ensuring model repo exists at ${MODEL_ROOT}/repo ..."
sudo mkdir -p "${MODEL_ROOT}/repo"
sudo chown -R "$USER":"$USER" "${MODEL_ROOT}/repo" || true

echo "Stopping any existing container ${CONTAINER_NAME}..."
docker rm -f "${CONTAINER_NAME}" >/dev/null 2>&1 || true

echo "Starting Triton container..."
docker run -d --restart unless-stopped --name "${CONTAINER_NAME}" --gpus all \
  -p 8000:8000 -p 8001:8001 -p 8002:8002 \
  -v "${MODEL_ROOT}":/models \
  nvcr.io/nvidia/tritonserver:${TRITON_TAG} tritonserver \
  --model-repository=/models/repo \
  --pinned-memory-pool-byte-size=268435456 \
  --cuda-memory-pool-byte-size=0:268435456 \
  --response-cache-byte-size=268435456

echo "Triton started. Checking logs for pinned memory and NVML..."
sleep 3
docker logs "${CONTAINER_NAME}" --tail=120 | egrep -i "pinned|NVML|Started HTTPService" || true

echo "If needed, create K8s Service/Endpoints to ${HOST_IP}:8000/8001/8002 for cluster access."

