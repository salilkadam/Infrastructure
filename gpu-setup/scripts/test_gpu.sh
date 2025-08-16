#!/usr/bin/env bash
set -euo pipefail
MODE=${1:-basic}
POD_NAME=nvidia-smi-test-${MODE}
MANIFEST_DIR="$(dirname "$0")/../manifests"
YAML="$MANIFEST_DIR/nvidia-smi-${MODE}.yaml"
if [[ ! -f "$YAML" ]]; then echo "Unknown mode: $MODE" >&2; exit 2; fi
kubectl delete -f "$YAML" --ignore-not-found | cat
echo "Applying $YAML" && kubectl apply -f "$YAML" | cat
SECS=0; while (( SECS < 90 )); do PHASE=$(kubectl get pod "$POD_NAME" -o jsonpath={.status.phase} 2>/dev/null || echo Pending); echo "Status: $PHASE (${SECS}s)"; [[ "$PHASE" == "Running" || "$PHASE" == "Succeeded" || "$PHASE" == "Failed" ]] && break; sleep 3; SECS=$((SECS+3)); done
kubectl describe pod "$POD_NAME" | sed -n /Events:/, | cat || true
kubectl logs "$POD_NAME" | cat || true
