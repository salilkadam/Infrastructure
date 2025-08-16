# Triton Inference Server (GPU)

This kustomization deploys NVIDIA Triton Inference Server with:
- 1 replica, requesting `nvidia.com/gpu: 1`
- Model repository mounted from PVC `triton-model-repo` using `fast-local-ssd` StorageClass
- Metrics scraped by Prometheus via pod annotations
- Ingress via nginx on `triton.askcollections.com`

Prereqs:
- `nvidia-device-plugin` deployed and reporting GPUs
- `RuntimeClass` named `nvidia` present in the cluster
- StorageClass `fast-local-ssd` available

Ports:
- HTTP: 8000
- gRPC: 8001
- Metrics: 8002
