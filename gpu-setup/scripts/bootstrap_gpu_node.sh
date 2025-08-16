#!/usr/bin/env bash
set -euo pipefail
NODE=${NODE:-gpu-server}
NAMESPACE=${NAMESPACE:-nvidia-device-plugin}
BASE_DIR="$(cd "$(dirname "$0")/.." && pwd)"

info() { printf "\n==> %s\n" "$*"; }

info "Environment report"
if command -v nvidia-smi >/dev/null 2>&1; then
  printf "Driver: %s\n" "$(nvidia-smi --query-gpu=driver_version --format=csv,noheader | head -n1)"
else
  echo "Driver: nvidia-smi not found"
fi
(command -v nvidia-ctk >/dev/null 2>&1 && nvidia-ctk --version | head -n1) || echo "nvidia-ctk not found"
containerd --version || true
runc --version | head -n1 || true

info "Checking containerd CDI settings"
if grep -q "enable_cdi = true" /etc/containerd/config.toml 2>/dev/null; then
  echo "containerd CDI enabled"
else
  echo "WARN: enable_cdi not found in /etc/containerd/config.toml. See $BASE_DIR/README.md and $BASE_DIR/configs/containerd/config.toml"
fi

info "Generating/refreshing CDI spec at /etc/cdi/nvidia.yaml"
"$BASE_DIR/scripts/generate_cdi_spec.sh" /etc/cdi/nvidia.yaml

info "Deploying NVIDIA device plugin"
"$BASE_DIR/scripts/setup_device_plugin.sh"

info "Pre-pulling CUDA images (optional)"
"$BASE_DIR/scripts/prepull_images.sh" || true

info "Testing GPU (basic)"
"$BASE_DIR/scripts/test_gpu.sh" basic || true

info "Testing GPU (CDI)"
"$BASE_DIR/scripts/test_gpu.sh" cdi || true

info "Done"
