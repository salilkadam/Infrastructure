# Triton Serving - Implementation Tracker

- [x] Phase 0: Discovery against live k3s
- [x] Phase 1: GPU device plugin present
- [x] Phase 2: RuntimeClass `nvidia` present
- [x] Phase 3: PVC using `fast-local-ssd`
- [x] Baseline manifests under `applications/triton/base`
- [x] ArgoCD `applications/triton/argocd-app.yaml`
- [ ] Prometheus scrape config for Triton metrics (confirm autodiscovery via annotations)
- [ ] HPA custom metric via Prometheus Adapter (or KEDA) configured
- [ ] Initial models populated in PVC
- [ ] Load test and tune model configs
