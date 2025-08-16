#!/usr/bin/env bash
set -euo pipefail
NAMESPACE=${NAMESPACE:-nvidia-device-plugin}
NODE=${NODE:-gpu-server}
kubectl get ns "$NAMESPACE" >/dev/null 2>&1 || kubectl create ns "$NAMESPACE"
kubectl delete ds -n kube-system nvdp-nvidia-device-plugin --ignore-not-found || true
kubectl delete ds -n kube-system nvdp-nvidia-device-plugin-mps-control-daemon --ignore-not-found || true
kubectl label node "$NODE" nvidia.com/gpu.present=true --overwrite
kubectl apply -n "$NAMESPACE" -f "$(dirname "$0")/../manifests/nvidia-device-plugin.yaml"
kubectl -n "$NAMESPACE" rollout status ds/nvidia-device-plugin-daemonset --timeout=120s | cat
