# Triton Serving - Implementation Plan

## Phases

- Phase 0 – Discovery (done)
  - Inspect live k3s cluster, GPU resources, storage classes, ingress conventions.
- Phase 1 – GPU prerequisites
  - Ensure `nvidia-device-plugin` is running (present).
  - Confirm `RuntimeClass` `nvidia` exists (present in repo).
- Phase 2 – Kubernetes GPU wiring
  - Node selector `nvidia.com/gpu.present=true`, runtimeClass `nvidia`.
- Phase 3 – Storage for models
  - Use existing StorageClass `fast-local-ssd` to provision `triton-model-repo` PVC (200Gi).
- Phase 4 – Observability
  - Triton exposes metrics on :8002; annotations enable Prom scraping.
  - Extend Prometheus config for Triton service discovery if needed.
- Phase 5 – Triton baseline deployment
  - Deploy 1 replica, `nvidia.com/gpu: 1`, ingress HTTP and gRPC.
- Phase 6 – GPU utilization
  - Configure per-model `config.pbtxt` with dynamic batching, instance groups.
- Phase 7 – Autoscaling
  - Prefer Prometheus Adapter for HPA custom metrics; fallback KEDA.
- Phase 8 – Ingress
  - nginx ingress with cert-manager Let's Encrypt (existing).
- Phase 9 – CI/CD
  - ArgoCD Application defined; pushing to repo triggers sync.

## Tests

- Sanity: `nvidia-smi` pod on GPU node; verify 1 allocatable GPU.
- Deploy Triton; check readiness, metrics endpoint.
- Send sample inference request; validate response and latency.
- Metrics: verify Prometheus scrapes `triton` job.

## Open Items

- Confirm domain names `triton.askcollections.com` and `triton-grpc.askcollections.com` or provide alternatives.
- Provide initial models and repository structure to mount into PVC.
